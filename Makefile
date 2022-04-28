.PHONY: all
all: release

.PHONY: clean
clean:
	rm -rf input output

.PHONY: release
release:
	docker build .

.PHONY: run-local
run-local:
	mkdir -p input output
	cp test/config.json input/config.json
	cp test/aqua_par.json input/aqua_par.json
	cp test/adult_par.json input/adult_par.json
	./bin/run-model ./input/config.json ./input/adult_par.json ./input/aqua_par.json ./output/data.json ./schema/config.json ./schema/adult_par.json ./schema/aqua_par.json ./schema/output.json