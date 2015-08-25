# TOOLS
GIT = /usr/bin/git

# REVISION INFO
HOSTNAME := $(shell hostname)
COMMIT := $(shell $(GIT) rev-parse HEAD)
REV_HASH := $(shell $(GIT) log --format='%h' -n 1)
REV_TAGS := $(shell $(GIT) describe --abbrev=0 --tags --always)
BRANCH := $(shell echo $(GIT_BRANCH)|cut -f2 -d"/")
PY_VERSION := $(shell cat setup.py | grep PILLOW_VERSION | grep -v version | tr -d ' ' | cut -f2 -d"=" | sed "s/[,\']//g")
VERSION_JSON = PIL/version.json

all: build

version:
	@-echo "Building version info in $(VERSION_JSON)"
	echo "{\n\t\"hash\": \"$(REV_HASH)\"," > $(VERSION_JSON)
	echo "\t\"version\": \"$(PY_VERSION)\"," >> $(VERSION_JSON)
	echo "\t\"hostname\": \"$(HOSTNAME)\"," >> $(VERSION_JSON)
	echo "\t\"commit\": \"$(COMMIT)\"," >> $(VERSION_JSON)
	echo "\t\"branch\": \"$(BRANCH)\"," >> $(VERSION_JSON)
	echo "\t\"tags\": \"$(REV_TAGS)\"\n}" >> $(VERSION_JSON)

clean:
	find . -type f -name "*.py[c|o]" -exec rm -f {} \;
	find . -type f -name "*.edited" -exec rm -f {} \;
	find . -type f -name "*.orig" -exec rm -f {} \;
	find . -type f -name "*.swp" -exec rm -f {} \;
	python setup.py clean
	rm PIL/*.so || true
	rm -r build || true
	find . -name __pycache__ | xargs rm -r || true
	rm -f $(VERSION_JSON)
	rm -rf dist

build: clean version
	python setup.py sdist
	python setup.py bdist_wheel


# https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
.PHONY: clean coverage doc docserve help inplace install install-req release-test sdist test upload upload-test
.DEFAULT_GOAL := release-test

coverage: 
	coverage erase
	coverage run --parallel-mode --include=PIL/* selftest.py
	nosetests --with-cov --cov='PIL/' --cov-report=html Tests/test_*.py
# Doesn't combine properly before report, writing report instead of displaying invalid report.
	rm -r htmlcov || true
	coverage combine
	coverage report

doc:
	$(MAKE) -C docs html

docserve:
	cd docs/_build/html && python -mSimpleHTTPServer 2> /dev/null&

help:
	@echo "Welcome to Pillow development. Please use \`make <target>' where <target> is one of"
	@echo "  clean          remove build products"
	@echo "  coverage       run coverage test (in progress)"
	@echo "  doc            make html docs"
	@echo "  docserve       run an http server on the docs directory"
	@echo "  html           to make standalone HTML files"
	@echo "  inplace        make inplace extension" 
	@echo "  install        make and install"
	@echo "  install-req    install documentation and test dependencies"
	@echo "  release-test   run code and package tests before release"
	@echo "  test           run tests on installed pillow"
	@echo "  upload         build and upload sdists to PyPI" 
	@echo "  upload-test    build and upload sdists to test.pythonpackages.com"

inplace: clean
	python setup.py build_ext --inplace

install:
	python setup.py install
	python selftest.py --installed

install-req:
	pip install -r requirements.txt

release-test:
	$(MAKE) install-req
	python setup.py develop
	python selftest.py
	nosetests Tests/test_*.py
	python setup.py install
	python test-installed.py
	check-manifest
	pyroma .
	viewdoc

sdist:
	python setup.py sdist --format=gztar,zip

test:
	python test-installed.py

# https://docs.python.org/2/distutils/packageindex.html#the-pypirc-file
upload-test:
#       [test]
#       username:
#       password:
#       repository = http://test.pythonpackages.com
	python setup.py sdist --format=gztar,zip upload -r test

upload:
	python setup.py sdist --format=gztar,zip upload
