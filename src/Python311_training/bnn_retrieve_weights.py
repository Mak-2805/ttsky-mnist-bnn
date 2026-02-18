import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"
import tensorflow as tf
import numpy as np
import larq as lq

output = True

def extract_weights(model):
	for i, layer in enumerate(model.layers):

		if isinstance(layer, (lq.layers.QuantConv2D, lq.layers.QuantDense)):
			w = layer.get_weights()[0] # No biases only need [0] for weights
			binary_w = np.where(w>0, 1, 0)

			if len(binary_w.shape) == 4:
				binary_w = np.transpose(binary_w, (3,0,1,2))
			else:
				binary_w = np.transpose(binary_w)
		
			filename = f"./src/Python311_training/weights/layer_{i}_weights.csv"
			if output:
				with open(filename, "w") as file:
					for neuron_weights in binary_w:
						bit_string = ",".join(map(str, neuron_weights.flatten()))
						file.write(f"{bit_string}\n")
			print(f"Created {filename} with shape {binary_w.shape}")
			print(f"strides: {layer}")


		if isinstance(layer, tf.keras.layers.BatchNormalization):
			prev = model.layers[i-1]

			if isinstance(prev, (lq.layers.QuantConv2D, lq.layers.QuantDense)):

				weights = layer.get_weights()
				if len(weights) == 3:
					beta, mean, var = weights
					gamma = np.ones_like(beta)
				else:
					gamma, beta, mean, var = weights
				eps = layer.epsilon

				N = np.prod(prev.get_weights()[0].shape[:-1])
				t_math = mean - (beta * np.sqrt(var + eps) / gamma)
				t_hardware = np.ceil((t_math + N) / 2).astype(int)
				#print(f"Layer: {i}, n: {N} t_math: {t_math} t_hardware: {t_hardware}")

				if (output):
					filename = f"./src/Python311_training/weights/layer_{i}_thresholds.csv"
					with open(filename, 'w') as file:
						for t in t_hardware:
							file.write(f"{t:08b}\n")
				print(f"Created {filename} (Thresholds for {prev.name})")

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

extract_weights(model)