package mnist_bnn_pkg;

    typedef enum logic [2:0] {
        s_IDLE    = 3'b000,
        s_LOAD    = 3'b001,
        s_LAYER_1 = 3'b010,
        s_LAYER_2 = 3'b011,
        s_LAYER_3 = 3'b100
    } state_t;

endpackage
