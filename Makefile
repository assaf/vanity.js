# Run all tests in all modules
default : test
test :
	for dir in */Makefile ; do \
		cd $$(dirname $${dir}) ; \
	 	make test || exit 1 ; \
	 	cd - ; \
	done

# Setup all modules
setup :
	for dir in */Makefile ; do \
		cd $$(dirname $${dir}) ; \
	 	make setup || exit 1 ; \
	 	cd - ; \
	done

