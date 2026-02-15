import numpy as np
import struct
from array import array
from os.path import join

THRESHOLD = 127

class MnistDataSaver(object):
    def __init__(self, training_images_filepath):
        self.training_images_filepath = training_images_filepath
    
    def save_binary_images(self):

        # Read data and make binary
        with open(self.training_images_filepath, 'rb') as file:
            magic, size, rows, cols = struct.unpack(">IIII", file.read(16))
            if magic != 2051:
                raise ValueError(f"Magic number mismatch, expected 2051, got {magic}")
            image_data = np.frombuffer(file.read(), dtype=np.uint8)
            image_data = (image_data > THRESHOLD).astype(np.uint8)
            newsize = int(size * 0.9)
            print(f"size: {size} newsize: {newsize}")
            image_data1 = image_data[:newsize * rows * cols]
            image_data2 = image_data[(newsize * rows * cols):]
            image_data1 = np.packbits(image_data1)
            image_data2 = np.packbits(image_data2)

        # Write binary training image data
        with open("training_data/mnist_binary_training.ubin", 'wb') as file:
            header = struct.pack(">IIII", magic, newsize, rows, cols)
            file.write(header)

            file.write(image_data1.tobytes())
            print("Successfully saved training data as binary!");

        # Write binary verifying image data
        with open("training_data/mnist_binary_verifying.ubin", 'wb') as file:
            header = struct.pack(">IIII", magic, size-newsize, rows, cols)
            file.write(header)

            file.write(image_data2.tobytes())
            print("Successfully saved verification data as binary!");

        # Write labels for training data

        with open("training_data/train-labels-idx1-ubyte/train-labels.idx1-ubyte", 'rb') as file:
            magic, size = struct.unpack(">II", file.read(8))
            labels = np.frombuffer(file.read(), np.uint8)
            labels_data1 = labels[:newsize]
            labels_data2 = labels[newsize:]
        
        with open("training_data/mnist_labels_binary_training.ubin", 'wb') as file:
            header = struct.pack(">II", magic, newsize)

            file.write(header)
            file.write(labels_data1.tobytes())
            print("Successfully saved training labels!")

        # Write labels for verifying data

        with open("training_data/mnist_labels_binary_verifying.ubin", 'wb') as file:
            header = struct.pack(">II", magic, size-newsize)

            file.write(header)
            file.write(labels_data2.tobytes())
            print("Successfully saved verifying labels!")

input_path = "training_data/"
training_images_filepath = join(input_path, 'train-images-idx3-ubyte/train-images.idx3-ubyte')

mnistdatasaver = MnistDataSaver(training_images_filepath, )

mnistdatasaver.save_binary_images()
