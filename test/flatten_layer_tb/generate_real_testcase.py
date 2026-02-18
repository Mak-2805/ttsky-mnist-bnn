import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"

import larq as lq
import tensorflow as tf
import numpy as np
import struct
import random

# Every time this module is run, a layer_inputs.mem file is created in the current_test_cases_values directory that contains the inputs to the final layer
# The associated label for the inputs is also generated and placed in the label.mem file

# To use this module for the testbench, first generate the .mem files by running this script, then run the testbench where the 3rd testcase will
# automatically load in the generated values for verification

images_verifying_filepath = "./src/Python311_training/training_data/mnist_binary_verifying.ubin"
labels_verifying_filepath = "./src/Python311_training/training_data/mnist_binary_labels_verifying.ubin"
script_location = os.path.dirname(__file__)

with open(images_verifying_filepath, 'rb') as file:
	magic, size, rows, cols = struct.unpack(">IIII", file.read(16))
	image_index_to_get = random.randint(0, size) # Index in MNIST data to test
	if magic != 2051:
		raise ValueError(f"Magic number incorrect, should be 2051, was {magic}")
	verifying_image_data = np.frombuffer(file.read(), dtype=np.uint8)
	verifying_image_data = np.unpackbits(verifying_image_data)
	test_image = verifying_image_data[(image_index_to_get) * rows * cols:(image_index_to_get+1) * rows * cols].reshape(1, rows, cols)
	print(test_image)

with open(labels_verifying_filepath, 'rb') as file:
	magic, size = struct.unpack(">II", file.read(8))
	if magic != 2049:
		raise ValueError(f"Magic number incorrect, should be 2049, was {magic}")
	verifying_labels = np.frombuffer(file.read(), dtype=np.uint8)



def get_layer_weights(model, layer_name):
	weights = ((model.get_layer(name=layer_name).get_weights()[0]) > 0).astype(np.uint8)
	weights = np.transpose(weights)

	path = os.path.join(script_location, 'current_test_case_values/layer_inputs.mem')
	with open(path, 'w') as file:
		for channel_to_output in range(0, 10):
			file.write(''.join(map(str,weights[channel_to_output])) + "\n")
	print(f"Wrote inputs to file: {path}")

def get_input_values(model, layer_name):
	extractor_model = tf.keras.Model(inputs=model.inputs, outputs=model.get_layer(layer_name).output)
	layer_output = extractor_model.predict(test_image)

	print(f"Shape of extracted output: {layer_output.shape}")

	layer_output = (layer_output > 0).astype(np.uint8)
	path = os.path.join(script_location, 'current_test_case_values/layer_inputs.mem')
	with open(path, 'w') as file:
			file.write(''.join(map(str,layer_output[0])))
	print(f"Wrote inputs to file: {path}")

def get_image_label():
	path = os.path.join(script_location, 'current_test_case_values/label.mem')
	with open(path, 'w') as file:
			file.write(''.join(map(str,bin(verifying_labels[image_index_to_get])))[2:])
	print(f"Wrote image label to file: {path}")

model_path = "./src/Python311_training/mnist_bnn_unconverted.h5"
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

#get_layer_weights(model, quant_dense) # STAYS THE SAME, SHOULD ONLY NEED TO BE RUN ONCE EVER
get_input_values(model, 'flatten')
get_image_label()

