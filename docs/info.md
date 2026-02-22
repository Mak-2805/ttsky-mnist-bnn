<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
<<<<<<< Updated upstream
=======

>>>>>>> Stashed changes
-->

## How it works

Explain how your project works

The network is trained in Python using Tensor Flow. Weights are binarized (±1) and batch normalization is replaced by a threshold comparison on the XNOR popcount, making the entire forward pass implementable with simple logic gates.

Refereing to BNN_Diagram.png
| Layer | Input | Output | Operations |
|---|---|---|---|
| Conv 1 (layer 1)| 28×28×1 | 14×14×8 | XNOR conv (8 filters, 3×3), threshold BatchNorm, 2×2 MaxPool |
| Conv 2 (layer 2)| 14×14×8 | 7×7×4 | XNOR conv (4 filters, 3×3), threshold BatchNorm, 2×2 MaxPool |
| Dense (layer 3)| 196 bits | 10 neurons | Binary dot product → 4-bit index |

Refering to High_Level_Circuit_Diagram.png
The FSM sequences through five states: IDLE → LOAD → LAYER_1 → LAYER_2 → LAYER_3. Each convolutional layer computes one output pixel per cycle using combinational XNOR + popcount logic. The final dense layer selects the winning neuron.


## How to test

<<<<<<< Updated upstream
Explain how to use your project

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
=======
1. Assert `ui[0]` (Mode = 1) to enter load mode.
2. Clock in pixel data via `ui[1]` (784 bits, row-major) and weight data via `ui[2]` (Layer 1: 72 bits, Layer 2: 288 bits, Layer 3: 1,960 bits) serially.
3. De-assert `ui[0]` to run inference.
4. Read the predicted digit from `uo[3:0]`.
>>>>>>> Stashed changes
