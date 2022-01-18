import numpy as np
from Cython.Build import cythonize


def build(setup_kwargs):
    setup_kwargs.update({
        'ext_modules': cythonize([
            "copium/*.pyx",
        ]),
        'include_dirs': [
            np.get_include(),
        ]
    })
