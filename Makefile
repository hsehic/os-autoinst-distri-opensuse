PERL5LIB_:=../..:os-autoinst:lib:tests/installation:tests/x11:tests/qa_automation:tests/virt_autotest:$$PERL5LIB

.PHONY: all
all:

.PHONY: help
help:
	echo "Call 'make test' to call tests"

.PHONY: prepare
prepare:
	git clone git://github.com/os-autoinst/os-autoinst
	$(MAKE) check-links
	cd os-autoinst && cpanm -nq --installdeps .
	cpanm -nq --installdeps .

os-autoinst/:
	@test -d os-autoinst || (echo "Missing test requirements, \
link a local working copy of 'os-autoinst' into this \
folder or call 'make prepare' to install download a copy necessary for \
testing" && exit 2)

tools/tidy: os-autoinst/
	@test -e tools/tidy || ln -s ../os-autoinst/tools/tidy tools/
	@test -e tools/absolutize || ln -s ../os-autoinst/tools/absolutize tools/
	@test -e .perltidyrc || ln -s os-autoinst/.perltidyrc ./

tools/lib/: os-autoinst/
	@test -e tools/lib || ln -s ../os-autoinst/tools/lib tools/

.PHONY: check-links
check-links: tools/tidy tools/lib/ os-autoinst/

.PHONY: check-links
tidy: check-links
	tools/tidy --check

.PHONY: test-compile
test-compile: check-links
	export PERL5LIB=${PERL5LIB_} ; for f in `git ls-files "*.pm" || find . -name \*.pm|grep -v /os-autoinst/` ; do perl -c $$f 2>&1 | grep -v " OK$$" && exit 2; done ; true

.PHONY: test-compile-changed
test-compile-changed: os-autoinst/
	export PERL5LIB=${PERL5LIB_} ; for f in `git diff --name-only | grep '.pm'` ; do perl -c $$f 2>&1 | grep -v " OK$$" && exit 2; done ; true

.PHONY: test-metadata
test-metadata:
	tools/check_metadata $$(git ls-files "tests/**.pm")

.PHONY: test-metadata-changed
test-metadata-changed:
	tools/check_metadata $$(git diff --name-only | grep 'tests.*pm')

.PHONY: test-merge
test-merge:
	@REV=$$(git merge-base FETCH_HEAD master 2>/dev/null) ;\
	if test -n "$$REV"; then \
	  FILES=$$(git diff --name-only FETCH_HEAD `git merge-base FETCH_HEAD master 2>/dev/null` | grep 'tests.*pm') ;\
	  for file in $$FILES; do if test -f $$file; then \
	    tools/check_metadata $$file || touch failed; \
	    ${PERLCRITIC} $$file || touch failed ;\
	  fi ; done; \
	fi
	@test ! -f failed

.PHONY: test-dry
test-dry:
	export PERL5LIB=${PERL5LIB_} ; tools/detect_code_dups

.PHONY: test
test: tidy test-compile test-merge test-dry

PERLCRITIC=PERL5LIB=tools/lib/perlcritic:$$PERL5LIB perlcritic --quiet --gentle --include Perl::Critic::Policy::HashKeyQuote --include Perl::Critic::Policy::ConsistentQuoteLikeWords

.PHONY: perlcritic
perlcritic: tools/lib/
	${PERLCRITIC} .

