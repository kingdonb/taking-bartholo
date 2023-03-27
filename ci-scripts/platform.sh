#!/bin/bash

# Used in Docker build to set platform dependent variables

case $TARGETARCH in

    "amd64")
	echo "amd64" > /.platform
	echo "amd64" > /.csplatform
	# echo "" > /.compiler 
	;;
    "arm64") 
	echo "aarch64" > /.platform
	echo "arm64" > /.csplatform
	# echo "gcc-aarch64-linux-gnu" > /.compiler
	;;
  #   "arm")
	# echo "armv7-unknown-linux-gnueabihf" > /.platform
	# echo "gcc-arm-linux-gnueabihf" > /.compiler
	# ;;
esac
