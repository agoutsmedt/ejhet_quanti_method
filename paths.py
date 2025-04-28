import os
import re

# Get current working directory
cwd = os.getcwd()

# Initialize paths
data_path = None
jstor_raw_data = None

# Check conditions based on current directory
if re.search("goutsmed", cwd):
    if re.search("agoutsmedt", cwd):
        data_path = os.path.join(os.path.expanduser("~"), "Nextcloud", "Research", "data", "jstor")
        jstor_raw_data = os.path.join(os.path.expanduser("~"), "data", "jstor")
    else:
        data_path = os.path.join(os.path.expanduser("~"), "data", "jstor")
        jstor_raw_data = data_path
else:
    if re.search("Admin", cwd):
        data_path = r"C:\Users\Admin\MEGA\data\jstor"
        jstor_raw_data = data_path
    elif re.search("thomd", cwd):
        data_path = r"C:\Users\thomd\MEGA\data\jstor"
        jstor_raw_data = data_path

print(f"The path for data is {data_path}")

