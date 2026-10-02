module axi4_lite_pwm (
    input  wire        ACLK,
    input  wire        ARESETN,     // active-low reset

    // ---- Write Address Channel ----
    input  wire [3:0]  AWADDR,
    input  wire        AWVALID,
    output reg         AWREADY,

    // ---- Write Data Channel ----
    input  wire [31:0] WDATA,
    input  wire [3:0]  WSTRB,
    input  wire        WVALID,
    output reg         WREADY,

    // ---- Write Response Channel ----
    output reg [1:0]   BRESP,
    output reg         BVALID,
    input  wire        BREADY,

    // ---- Read Address Channel ----
    input  wire [3:0]  ARADDR,
    input  wire        ARVALID,
    output reg         ARREADY,

    // ---- Read Data Channel ----
    output reg [31:0]  RDATA,
    output reg [1:0]   RRESP,
    output reg         RVALID,
    input  wire        RREADY,

    // ---- Peripheral outputs ----
    output wire        PWM_OUT,     // to LED pin
    output wire        PWM_IRQ      // interrupt line
);

    // =========================================================
    // Internal registers (the "software-visible" state)
    // =========================================================
    reg        ctrl_enable;
    reg        ctrl_mode;
    reg [7:0]  duty;
    reg [15:0] period;
    reg        overflow_flag;

    // =========================================================
    // WRITE CHANNEL - simple 3-state FSM
    // =========================================================
    localparam W_IDLE = 2'd0;
    localparam W_DATA = 2'd1;
    localparam W_RESP = 2'd2;

    reg [1:0]  wstate;
    reg [3:0]  awaddr_reg;

    wire pwm_wrap; // forward declare (defined below)

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            wstate        <= W_IDLE;
            AWREADY       <= 1'b0;
            WREADY        <= 1'b0;
            BVALID        <= 1'b0;
            BRESP         <= 2'b00;
            ctrl_enable   <= 1'b0;
            ctrl_mode     <= 1'b0;
            duty          <= 8'd128;
            period        <= 16'd100;
            overflow_flag <= 1'b0;
            awaddr_reg    <= 4'd0;
        end
        else begin
            AWREADY <= 1'b0;
            WREADY  <= 1'b0;

            case (wstate)
                W_IDLE: begin
                    if (AWVALID) begin
                        AWREADY    <= 1'b1;
                        awaddr_reg <= AWADDR;
                        wstate     <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (WVALID) begin
                        WREADY <= 1'b1;
                        case (awaddr_reg)
                            4'h0: begin
                                if (WSTRB[0]) begin
                                    ctrl_enable <= WDATA[0];
                                    ctrl_mode   <= WDATA[1];
                                end
                            end
                            4'h4: begin
                                if (WSTRB[0]) duty <= WDATA[7:0];
                            end
                            4'h8: begin
                                if (WSTRB[0] && WDATA[1]) overflow_flag <= 1'b0;
                            end
                            4'hC: begin
                                if (WSTRB[0]) period[7:0]  <= WDATA[7:0];
                                if (WSTRB[1]) period[15:8] <= WDATA[15:8];
                            end
                            default: ;
                        endcase
                        wstate <= W_RESP;
                    end
                end

                W_RESP: begin
                    BVALID <= 1'b1;
                    BRESP  <= 2'b00;
                    if (BVALID && BREADY) begin
                        BVALID <= 1'b0;
                        wstate <= W_IDLE;
                    end
                end

                default: wstate <= W_IDLE;
            endcase

            if (pwm_wrap)
                overflow_flag <= 1'b1;
        end
    end

    // =========================================================
    // READ CHANNEL - simple 2-state FSM
    // =========================================================
    localparam R_IDLE = 1'd0;
    localparam R_RESP = 1'd1;

    reg        rstate;
    reg [3:0]  araddr_reg;

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            rstate     <= R_IDLE;
            ARREADY    <= 1'b0;
            RVALID     <= 1'b0;
            RRESP      <= 2'b00;
            RDATA      <= 32'd0;
            araddr_reg <= 4'd0;
        end
        else begin
            ARREADY <= 1'b0;

            case (rstate)
                R_IDLE: begin
                    if (ARVALID) begin
                        ARREADY    <= 1'b1;
                        araddr_reg <= ARADDR;
                        rstate     <= R_RESP;
                    end
                end

                R_RESP: begin
                    RVALID <= 1'b1;
                    RRESP  <= 2'b00;
                    case (araddr_reg)
                        4'h0: RDATA <= {30'b0, ctrl_mode, ctrl_enable};
                        4'h4: RDATA <= {24'b0, duty};
                        4'h8: RDATA <= {30'b0, overflow_flag, ctrl_enable};
                        4'hC: RDATA <= {16'b0, period};
                        default: RDATA <= 32'd0;
                    endcase
                    if (RVALID && RREADY) begin
                        RVALID <= 1'b0;
                        rstate <= R_IDLE;
                    end
                end

                default: rstate <= R_IDLE;
            endcase
        end
    end

    // =========================================================
    // PWM ENGINE
    // =========================================================
    reg [15:0] counter;
    reg [7:0]  breathe_duty;
    reg        breathe_dir;

    assign pwm_wrap = (counter == period - 1);

    always @(posedge ACLK) begin
        if (!ARESETN)
            counter <= 16'd0;
        else if (ctrl_enable) begin
            if (pwm_wrap)
                counter <= 16'd0;
            else
                counter <= counter + 1'b1;
        end
    end

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            breathe_duty <= 8'd0;
            breathe_dir  <= 1'b1;
        end
        else if (ctrl_enable && ctrl_mode && pwm_wrap) begin
            if (breathe_dir) begin
                if (breathe_duty == 8'd255)
                    breathe_dir <= 1'b0;
                else
                    breathe_duty <= breathe_duty + 1'b1;
            end
            else begin
                if (breathe_duty == 8'd0)
                    breathe_dir <= 1'b1;
                else
                    breathe_duty <= breathe_duty - 1'b1;
            end
        end
    end

    wire [7:0]  active_duty    = ctrl_mode ? breathe_duty : duty;
    wire [23:0] duty_threshold = (period * active_duty) >> 8;

    assign PWM_OUT = ctrl_enable && (counter < duty_threshold[15:0]);
    assign PWM_IRQ = overflow_flag;

endmodule
