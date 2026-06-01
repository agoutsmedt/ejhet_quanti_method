import os
import re
import getpass

# Get current working directory
cwd = os.getcwd()

# Get current user
user = getpass.getuser()


# Check conditions based on current directory
if re.search("goutsmed", cwd):
    if re.search("agoutsmedt", cwd):
        data_path = os.path.join(os.path.expanduser("~"), "Nextcloud")
        jstor_raw_data = os.path.join(os.path.expanduser("~"), "data", "jstor")
        ejhet_project_data_path = os.path.join(data_path, "ejhet_project")
    else:
        data_path = os.path.join(os.path.expanduser("~"), "data", "jstor")
        jstor_raw_data = data_path
else:
    if user in ("admin", "thom"):
        data_path = r"C:\cloud\data"
        jstor_data_path = os.path.join(data_path, "jstor")
        elsevier_data_path = os.path.join(data_path, "elsevier")
        ejhet_project_data_path = os.path.join(data_path, "ejhet_project")
        econ_embeddings_data_path = os.path.join(data_path, "econ_embeddings")


print(f"The path for data is {data_path}")

