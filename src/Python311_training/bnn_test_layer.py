import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"

import larq as lq
import tensorflow as tf
import numpy as np
import struct

images_verifying_filepath = "./training_data/mnist_binary_verifying.ubin"
labels_verifying_filepath = "./training_data/mnist_binary_labels_verifying.ubin"

image_index_to_get = 2 # Index in MNIST data to test
layer_to_get = 'max_pooling2d' # Layer name to read values from (CHANGED: Get after max pooling)
do_binarization = True # Binarize the output data
channel_to_output = 0 # Channel of layer to output (will print all channels below)
print_layer_weights = False # Print the binarized weights of layer_to_get (CHANGED: We have weights)

with open(images_verifying_filepath, 'rb') as file:
	magic, size, rows, cols = struct.unpack(">IIII", file.read(16))
	if magic != 2051:
		raise ValueError(f"Magic number incorrect, should be 2051, was {magic}")
	verifying_image_data = np.frombuffer(file.read(), dtype=np.uint8)
	verifying_image_data = np.unpackbits(verifying_image_data)
	test_image = verifying_image_data[(image_index_to_get-1) * rows * cols:(image_index_to_get) * rows * cols].reshape(1, rows, cols)
	print(test_image)

def get_layer_weights(model, layer_name):
	# Get max pooling output
	extractor_model = tf.keras.Model(inputs=model.inputs, outputs=model.get_layer(layer_name).output)
	layer_output = extractor_model.predict(test_image)

	print(f"\n{'='*60}")
	print(f"Shape of extracted output: {layer_output.shape}")
	print(f"{'='*60}\n")

	if (do_binarization):
		layer_output = (layer_output > 0).astype(np.uint8)

	# Get weights from quant_conv2d layer
	conv_weights = ((model.get_layer(name='quant_conv2d').get_weights()[0]) > 0).astype(np.uint8)
	conv_weights = np.transpose(conv_weights, (3,0,1,2))  # (channels, rows, cols)
	
	print("="*60)
	print("WEIGHTS FOR TESTBENCH (quant_conv2d layer)")
	print("="*60)
	for ch in range(8):
		weight_bits = conv_weights[ch].flatten()
		print(f"// channel {ch}: {weight_bits}")
	
	print("\n" + "="*60)
	print("EXPECTED OUTPUTS FOR TESTBENCH (SystemVerilog format)")
	print("Format: [row][col] with 8-bit packed as [ch7 ch6 ch5 ch4 ch3 ch2 ch1 ch0]")
	print("="*60 + "\n")
	
	# Pack outputs into 8-bit values for each (row, col) position
	print("parameter logic [13:0][13:0][7:0] EXPECTED_OUTPUT_MNIST = '{")
	for row in range(14):
		row_str = "    '{"
		col_values = []
		for col in range(14):
			# Pack all 8 channels at this (row, col) into one 8-bit value
			packed = 0
			for ch in range(8):
				if layer_output[0, row, col, ch]:
					packed |= (1 << ch)
			col_values.append(f"8'b{packed:08b}")
		row_str += ", ".join(col_values) + "}"
		if row < 13:
			row_str += ","
		row_str += f"  // row {row}"
		print(row_str)
	print("};")
	
	print("\n" + "="*60)
	print("HUMAN-READABLE: Channel outputs (first 3 rows for verification)")
	print("="*60 + "\n")
	for ch in range(8):
		print(f"Channel {ch}:")
		for row in range(3):
			row_data = layer_output[0, row, :, ch]
			print(f"  Row {row}: {row_data}")
		print()

model_path = "./mnist_bnn_unconverted.h5"
larq_custom_objects = {
	"QuantConv2D": lq.layers.QuantConv2D,
	"QuantDense": lq.layers.QuantDense,
	"ste_sign": lq.quantizers.ste_sign,
	"weight_clip": lq.constraints.weight_clip
}

if os.path.exists(model_path):
	model = tf.keras.models.load_model(model_path, custom_objects=larq_custom_objects)
	model.summary()
	print(f"Model loaded for extraction: {model_path}")
else:
	print(f"Model not loaded for extraction :(\n")
	exit()

get_layer_weights(model, layer_to_get)

