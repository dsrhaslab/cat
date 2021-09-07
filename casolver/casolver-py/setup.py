# -*- coding: utf-8 -*-

# Learn more: https://github.com/kennethreitz/setup.py

from setuptools import setup, find_packages

setup(
    name='casolver-py',
    version='0.1.0',
    description='',
    author='Tânia Esteves',
    author_email='tania_esteves@outlook.com',
    install_requires=[
        'ujson',
        'psutil',
        'numpy',
        'hlwy-lsh',
    ],
    test_suite='nose.collector',
    tests_require=['nose'],
    include_package_data=True,
    scripts=['casolver/bin/casolver-py.py'],
    entry_points={'console_scripts': ['casolver-py=casolver.core.casolver:main']}
)