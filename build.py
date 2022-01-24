import numpy as np
from distutils.command.build_ext import build_ext
from distutils.extension import Extension
from Cython.Build import cythonize


cy_extensions = [
    Extension(
        "*",
        [
            "copium/*.pyx",
        ],
        include_dirs=[
            np.get_include(),
        ],
        define_macros=[
            ("NPY_NO_DEPRECATED_API", "NPY_1_7_API_VERSION"),
        ]
    ),
]

extensions = [
    *cythonize(cy_extensions),
]


compile_args = {
    "msvc": ["/openmp", "/O2", "/fp:fast"],
    None: ["-fopenmp", "-O2", "-ffast-math"],
}
link_args = {
    "msvc": [],
    None: ["-fopenmp"],
}


class build_ext_subclass(build_ext):
    def build_extensions(self):
        compiler_type = self.compiler.compiler_type

        try:
            extra_compile_args = compile_args[compiler_type]
        except KeyError:
            extra_compile_args = compile_args[None]

        try:
            extra_link_args = link_args[compiler_type]
        except KeyError:
            extra_link_args = link_args[None]

        for extension in self.extensions:
            extension.extra_compile_args.extend(extra_compile_args)
            extension.extra_link_args.extend(extra_link_args)

        return super().build_extensions()


def build(setup_kwargs):
    setup_kwargs.update(
        {
            "ext_modules": extensions,
            "cmdclass": {
                "build_ext": build_ext_subclass,
            },
        }
    )
