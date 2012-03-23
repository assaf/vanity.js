default : test
.PHONY : test setup


# Run all tests in all modules
test :
	for make in */Makefile ; do cd $$(dirname $${make}) ; make test || exit 1 ; cd - ; done

# Setup all modules
setup :
	for make in */Makefile ; do cd $$(dirname $${make}) ; make setup || exit 1 ; cd - ; done
