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
#		llama-service:            install/configure the llama.cpp router
#		         services from the tracked config: beast.lan
#		         llama.service :2001 and llama-cpu.service :2002,
#		         athena.lan llama.service :2001 (all three, or TARGETS="...")
#		         It copies sources/config/*.applied.ini (the current
#		         mirror of each live preset) to /usr/local/etc, so a
#		         preset edit lands on the host, is re-captured into
#		         sources/config/, and is committed.
#		         It checks every preset key against the host binary and
#		         dry-runs the preset on a loopback scratch port before any
#		         restart, then backs up the live config and unit.
#		llama-service-dry-run:    the same checks; changes nothing
#		llama-service-verify:     live state only: active, restarts,
#		         /health, and the model list; changes nothing
#		backup-models:            archive each host's live HuggingFace cache
#		         to its /backups/huggingface/ (large spinning storage).
#		         Additive: a model dropped from the live cache stays in
#		         the archive. HOSTS="beast|athena|minerva|all".
#		         The laptop has no /backups volume, so its cache is
#		         archived on beast while the two are on the same subnet.
#		         Use --dry-run to preview.
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

TARGETS =
LLAMA_TARGETS = $(or $(TARGETS),--all)

llama-service:
	sh scripts/llama-service-install.sh $(LLAMA_TARGETS)

llama-service-dry-run:
	sh scripts/llama-service-install.sh $(LLAMA_TARGETS) --dry-run

llama-service-verify:
	sh scripts/llama-service-install.sh $(LLAMA_TARGETS) --verify-only

backup-models:
	sh scripts/backup-models.sh $(or $(HOSTS),all)

.PHONY: test capture site deploy clean llama-service llama-service-dry-run llama-service-verify backup-models
