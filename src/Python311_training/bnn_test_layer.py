import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"

import larq as lq
import tensorflow as tf
import numpy as np
import struct

images_verifying_filepath = "./src/Python311_training/training_data/mnist_binary_verifying.ubin"
labels_verifying_filepath = "./src/Python311_training/training_data/mnist_binary_labels_verifying.ubin"

image_index_to_get = 2 # Index in MNIST data to test
layer_to_get = 'quant_conv2d' # Layer name to read values from
do_binarization = True # Binarize the output data
channel_to_output = 7 # Channel of layer to output

with open(images_verifying_filepath, 'rb') as file:
	magic, size, rows, cols = struct.unpack(">IIII", file.read(16))
	if magic != 2051:
		raise ValueError(f"Magic number incorrect, should be 2051, was {magic}")
	verifying_image_data = np.frombuffer(file.read(), dtype=np.uint8)
	verifying_image_data = np.unpackbits(verifying_image_data)
	test_image = verifying_image_data[(image_index_to_get-1) * rows * cols:(image_index_to_get) * rows * cols].reshape(1, rows, cols)
	print(test_image)

def get_layer_weights(model, layer_name):
	extractor_model = tf.keras.Model(inputs=model.inputs, outputs=model.get_layer(layer_name).output)
	layer_output = extractor_model.predict(test_image)

	print(f"Shape of extracted output: {layer_output.shape}")

	if (do_binarization):
		layer_output = (layer_output > 0).astype(np.uint8)

	print(layer_output[0][channel_to_output])

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

get_layer_weights(model, layer_to_get)

