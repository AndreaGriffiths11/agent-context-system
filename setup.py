"""Setup configuration for agent-context package."""

from setuptools import setup, find_packages
from pathlib import Path

# Read README
readme_file = Path(__file__).parent / "README.md"
long_description = readme_file.read_text(encoding="utf-8") if readme_file.exists() else ""

setup(
    name="agent-context",
    version="0.2.1",
    description="Production-tested memory system for AI agents",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="Andrea Griffiths",
    author_email="andrea@mainbranch.dev",
    url="https://github.com/AndreaGriffiths11/agent-context-system",
    license="Apache-2.0",
    packages=find_packages(exclude=["tests", "tests.*", "examples", "docs"]),
    python_requires=">=3.10",
    install_requires=[
        # Zero dependencies for file-based core
    ],
    extras_require={
        "dev": [
            "pytest>=7.0",
            "pytest-cov>=4.0",
        ],
        "semantic": [
            "sentence-transformers>=2.0",
            # Future: sqlite-vec integration
        ],
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: Apache Software License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
    ],
    keywords="ai agents memory rag context llm",
)
