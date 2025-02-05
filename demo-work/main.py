def add_two_integers(a: int, b: int) -> int:  # -> Any:
    return a + b


def add_two_floats(a: float, b: float) -> float:  # -> Any:
    return a + b


def concentenate_two_strings(a: str, b: str) -> str:  # -> Any:
    return a + b


def main() -> None:
    print(add_two_integers(1, 2))
    print(add_two_floats(1.0, 2.0))
    print(
        concentenate_two_strings(
            "Hello HelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHello",
            "World",
        )
    )


if __name__ == "__main__":
    main()
