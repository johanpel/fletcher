#!/usr/bin/env python3

# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from setuptools.command.egg_info import egg_info as _egg_info
from setuptools import setup, Extension, find_packages
from distutils.command.bdist import bdist as _bdist
from distutils.command.build import build as _build
from distutils.command.clean import clean as _clean
from distutils.command.sdist import sdist as _sdist

import os
import platform
import shutil
import glob
import numpy as np
import pyarrow as pa


def read(fname):
    with open(os.path.join(os.path.dirname(__file__), fname)) as f:
        return f.read()


target_dir = os.getcwd() + "/build"
output_dir = target_dir + "/install"
include_dir = output_dir + "/include"
lib_dirs = [output_dir + "/lib", output_dir + "/lib64"]

py_target_dir = target_dir + "/python"
py_build_dir = py_target_dir + "/build"
py_dist_dir = target_dir + "/dist"


class clean(_clean):
    def run(self):
        _clean.run(self)
        try:
            [os.remove('pyfletcher/lib' + x) for x in ['.cpp', '.h', '_api.h']]
        except:
            pass
        shutil.rmtree(target_dir)


class build(_build):
    def initialize_options(self):
        _build.initialize_options(self)
        from plumbum import FG
        from plumbum.cmd import mkdir
        mkdir['-p'][py_build_dir] & FG
        self.build_base = py_build_dir

    def run(self):
        from plumbum import local, FG
        with local.cwd(target_dir):
            try:
                from plumbum.cmd import cmake, make
            except ImportError:
                # TODO: download cmake 3.14 and extract in build dir
                raise ImportError('CMake or make not found')
            cmake['../../..']['-DFLETCHER_BUILD_ECHO=ON']['-DCMAKE_BUILD_TYPE=Release'][
                '-DCMAKE_CXX_FLAGS=-D_GLIBCXX_USE_CXX11_ABI=0']['-DCMAKE_INSTALL_PREFIX={}'.format(output_dir)] & FG
            make['-j4'] & FG
            make['install'] & FG
        _build.run(self)


class bdist(_bdist):
    def finalize_options(self):
        _bdist.finalize_options(self)
        self.dist_dir = py_dist_dir


class sdist(_sdist):
    def finalize_options(self):
        _sdist.finalize_options(self)
        self.dist_dir = py_dist_dir


class egg_info(_egg_info):
    def initialize_options(self):
        _egg_info.initialize_options(self)
        self.egg_base = os.path.relpath(py_target_dir)


setup(
    name="pyfletcher",
    version="0.0.19",
    author="Accelerated Big Data Systems, Delft University of Technology",
    packages=find_packages(),
    description="A Python wrapper for the Fletcher runtime library",
    long_description=read('README.md'),
    long_description_content_type='text/markdown',
    url="https://github.com/abs-tudelft/fletcher",
    project_urls={
        "Bug Tracker": "https://github.com/abs-tudelft/fletcher/issues",
        "Documentation": "https://abs-tudelft.github.io/fletcher/",
        "Source Code": "https://github.com/abs-tudelft/fletcher/",
    },
    ext_modules=[
        Extension(
            "pyfletcher.lib",
            ["pyfletcher/lib.pyx"],
            language="c++",
            define_macros=[
                ("_GLIBCXX_USE_CXX11_ABI", "0")
            ],
            include_dirs=[
                np.get_include(),
                pa.get_include(),
                include_dir
            ],
            libraries=pa.get_libraries() + ["fletcher"],
            library_dirs=pa.get_library_dirs() + lib_dirs,
            runtime_library_dirs=pa.get_library_dirs() + lib_dirs,
            extra_compile_args=["-std=c++11", "-O3"],
            extra_link_args=["-std=c++11"]
        )
    ],
    install_requires=[
        'numpy >= 1.14',
        'pandas',
        'pyarrow == 4.0.1',
    ],
    setup_requires=[
        'cython',
        'numpy',
        'pyarrow == 4.0.1',
        'plumbum',
        'pytest-runner'
    ],
    tests_require=[
        'pytest'
    ],
    classifiers=[
        "Programming Language :: Python :: 3",
        "Programming Language :: Cython",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: Apache Software License",
        "Operating System :: POSIX :: Linux"
    ],
    cmdclass={
        'bdist': bdist,
        'build': build,
        'clean': clean,
        'egg_info': egg_info,
        'sdist': sdist,
    },
    license='Apache License, Version 2.0',
    zip_safe=False,
    data_files=[
        ('lib', [output_dir + '/lib64/libfletcher_echo.so']
         if 'AUDITWHEEL_PLAT' in os.environ else []),
    ],
)
