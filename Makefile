#
#	Makefile for the LLM-integration project.
#
#	Human-facing driver; each rule calls the appropriate tool:
#		test:    sh scripts/tests-run.sh
#		capture: refresh dataflow.in/endpoints/ from the live routers
#		site:    build the standard project page set into site.out/
#		deploy:  RETIRED - publishing goes through the homelab project
#		         (homelab-publish; see the homelab's
#		         documents/09-project-pages-conventions.md)
#		clean:   rm generated output (never touches dataflow.in captures)
#

test:
	sh scripts/tests-run.sh

capture:
	sh scripts/endpoints-capture.sh

site:
	sh scripts/site-pages.sh

deploy:
	@echo '==== RETIRED: publishing goes through the homelab project (homelab-publish).'
	@echo '==== Build the pages here (make site), then run the homelab''s "make deploy"'
	@echo '==== to publish (see homelab documents/09-project-pages-conventions.md).'

clean:
	rm -f dataflow.out/* site.out/* logs/*

.PHONY: test capture site deploy clean
