<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.

UPDATE MORE LATER!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! AND ADD THOSE VISIO IMAGES.
-->

## How it works

A Binary Neural Network (BNN) MNIST digit classifier. Pixel and weight data are loaded serially, then the network performs inference to predict a digit (0–9) output as a 4-bit value.

## How to test

1. Assert `ui[0]` (Mode = 1) to enter load mode.
2. Clock in pixel data via `ui[1]` and weight data via `ui[2]` serially.
3. De-assert `ui[0]` to run inference.
4. Read the predicted digit from `uo[3:0]`.

## External hardware

None.
