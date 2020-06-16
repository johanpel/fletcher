.PHONY: clean sim gui

all:
	python generate-input.py
	fletchgen -n Sum -r recordbatch.rb -s memory.srec -l vhdl --sim

sim:
	rm -f vhdl/Sum.gen.vhd
	vhdeps -i ${FLETCHER_DIR}/hardware -i . ghdl SimTop_tc

gui:
	rm -f vhdl/Sum.gen.vhd
	vhdeps -i ${FLETCHER_DIR}/hardware -i . --gui ghdl SimTop_tc

clean:
	# input files
	rm -f recordbatch.rb
	# vhdmmio stuff	
	rm -rf vhdmmio-doc
	rm -f fletchgen.mmio.yaml
	rm -f vhdmmio.log
	# fletchgen stuff
	rm -f memory.srec
	rm -rf dot
	rm -f vhdl/*.gen.vhd
