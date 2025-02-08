import sys
import os

# Add the root directory of the project to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


from aywork.config_schemas.config_schema import Config
from aywork.utils.config_utils import get_config


@get_config(config_path="../configs", config_name="config")
def entrypoint(config: Config) -> None:
    print(config)


if __name__ == "__main__":
    entrypoint()  # type: ignore
