#
#	Makefile for the LLM-integration project.
#
#	Human-facing driver; each rule calls the appropriate tool:
#		test:    sh scripts/tests-run.sh
#		capture: refresh dataflow.in/endpoints/ from the live routers
#		clean:   rm generated output (never touches dataflow.in captures)
#

test:
	sh scripts/tests-run.sh

capture:
	sh scripts/endpoints-capture.sh

clean:
	rm -f dataflow.out/* site.out/* logs/*

.PHONY: test capture clean
