from os import listdir
from os.path import isfile, join
import re
import random
import os
import sys, getopt


def get_filenames(data_dir, regex):
    # Create list with the training filenames
    return [f for f in listdir(data_dir) if test_file(data_dir, f, regex)]


def test_file(data_dir, file, regex):
    # Match file with regex
    match = re.search(regex, file)

    # Check if file exists and matches regex
    if isfile(join(data_dir, file)) and match:
        return True

    else:
        return False


def get_shuffled_fns_path():
    # Get HOME environment var
    home = os.environ['HOME']
    # Get DL Caching lib path
    dl_caching_dir = home + "/dlcaching"

    # Create DL caching dir if necessary
    if not os.path.exists(dl_caching_dir):
        print("DL Caching directory " + dl_caching_dir + " created.")
        os.makedirs(dl_caching_dir)

    return dl_caching_dir + "/shuffled_filenames.txt"


def shuffle(data_dir, regex, num_epochs):
    # Get filenames list
    filenames = get_filenames(data_dir, regex)

    # Check if filenames list is empty
    if not filenames:
        print("No training filenames found in" + data_dir)

    # Open out file
    shuffled_filenames_path = get_shuffled_fns_path()
    out_file = open(shuffled_filenames_path, "w")

    # Repeat for the number of epochs
    for i in range(num_epochs):

        # Shuffle filenames
        random.shuffle(filenames)

        # Write filename
        for f in filenames:
            file_path = data_dir + "/" + f
            out_file.write("%s\n" % file_path)

    print("Shuffled filenames file " + shuffled_filenames_path + " created.")

    # Close out file
    out_file.close()


def main(argv):
    data_dir = ''
    regex = ''
    epochs = 0

    try:
        opts, args = getopt.getopt(argv, "hd:r:e:", ["data_dir=", "regex=", "epochs="])
    except getopt.GetoptError:
        print('shuffle_filenames.py -d <data_dir> -r <regex> -e <num_epochs>')
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print('shuffle_filenames.py -d <data_dir> -r <regex> -e <num_epochs>')
            sys.exit()
        elif opt in ("-d", "--data_dir"):
            data_dir = arg
        elif opt in ("-r", "--regex"):
            regex = arg
        elif opt in ("-e", "--epochs"):
            epochs = int(arg)

    shuffle(data_dir, regex, epochs)


if __name__ == "__main__":
    main(sys.argv[1:])
