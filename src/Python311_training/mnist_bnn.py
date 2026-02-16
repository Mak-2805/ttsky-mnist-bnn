import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"

import larq as lq
import tensorflow as tf
import numpy as np
import struct

# Need larq, tensorflow, tf_keras (for legacy support)

images_training_filepath = "./src/Python311_training/training_data/mnist_binary_training.ubin"
labels_training_filepath = "./src/Python311_training/training_data/mnist_binary_labels_training.ubin"
images_verifying_filepath = "./src/Python311_training/training_data/mnist_binary_verifying.ubin"
labels_verifying_filepath = "./src/Python311_training/training_data/mnist_binary_labels_verifying.ubin"


with open(images_training_filepath, 'rb') as file:
    magic, size, rows, cols = struct.unpack(">IIII", file.read(16))
    if magic != 2051:
        raise ValueError(f"Magic number incorrect, should be 2051, was {magic}")
    training_image_data = np.frombuffer(file.read(), dtype=np.uint8)
    training_image_data = np.unpackbits(training_image_data)
    training_images = training_image_data[:size * rows * cols].reshape(size, rows, cols)

with open(labels_training_filepath, 'rb') as file:
    magic, size = struct.unpack(">II", file.read(8))
    if magic != 2049:
        raise ValueError(f"Magic number incorrect, should be 2049, was {magic}")
    training_labels = np.frombuffer(file.read(), dtype=np.uint8)

with open(images_verifying_filepath, 'rb') as file:
    magic, size, rows, cols = struct.unpack(">IIII", file.read(16))
    if magic != 2051:
        raise ValueError(f"Magic number incorrect, should be 2051, was {magic}")
    verifying_image_data = np.frombuffer(file.read(), dtype=np.uint8)
    verifying_image_data = np.unpackbits(verifying_image_data)
    verifying_images = verifying_image_data[:size * rows * cols].reshape(size, rows, cols)

with open(labels_verifying_filepath, 'rb') as file:
    magic, size = struct.unpack(">II", file.read(8))
    if magic != 2049:
        raise ValueError(f"Magic number incorrect, should be 2049, was {magic}")
    verifying_labels = np.frombuffer(file.read(), dtype=np.uint8)

kwargs = dict(input_quantizer="ste_sign",
              kernel_quantizer="ste_sign",
              kernel_constraint="weight_clip",
              use_bias=False)

#16,4
model = tf.keras.models.Sequential()
model.add(lq.layers.QuantConv2D(8, (3,3), kernel_quantizer="ste_sign", kernel_constraint="weight_clip", use_bias=False, padding="same", input_shape=(28,28,1)))
model.add(tf.keras.layers.BatchNormalization(scale=False))
model.add(tf.keras.layers.MaxPooling2D((2,2)))



model.add(lq.layers.QuantConv2D(4, (3,3), padding="same", **kwargs))
model.add(tf.keras.layers.BatchNormalization(scale=False))
model.add(tf.keras.layers.MaxPooling2D((2,2)))

model.add(tf.keras.layers.Flatten())

model.add(lq.layers.QuantDense(10, **kwargs))
model.add(tf.keras.layers.BatchNormalization(scale=False))
model.add(tf.keras.layers.Activation("softmax"))

model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

model.fit(training_images, training_labels, batch_size=64, epochs=20)

test_loss, test_acc = model.evaluate(verifying_images, verifying_labels)

print(f"Test accuracy {test_acc * 100:.2f} %")

model.save("./src/Python311_training/mnist_bnn_unconverted.h5")