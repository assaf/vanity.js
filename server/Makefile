default : test
.PHONY : test setup


# Run all tests
test :
	mocha -R tap 


# Run this in production
install :
	npm install


# Setup everything
setup :
	npm install


# Create fake data for testing
fake :
	coffee lib/fake_it 10000


# UI for ElasticSearch
es-view :
	dir=/usr/local/Cellar/elasticsearch/* ;\
	if [[ ! -f $${dir}/plugins/head/index.html ]] ; then \
		echo "Installing ElasticSearch head ..." ; \
		$${dir}/bin/plugin -install mobz/elasticsearch-head ; \
  fi
	open http://localhost:9200/_plugin/head/

