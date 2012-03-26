default : test
.PHONY : test setup


# Run all tests
test :
	mocha -R list 


# Run this in production
install :
	npm install


# Setup everything
setup :
	npm install


# Deletes ElasticSearch index
es-delete :
	#coffee lib/fake_it

# Populates ElasticSearch with fake data
es-fake :
	coffee lib/fake_it

# UI for ElasticSearch
es-view :
	dir=/usr/local/Cellar/elasticsearch/* ;\
	if [[ ! -f $${dir}/plugins/head/index.html ]] ; then \
		echo "Installing ElasticSearch head ..." ; \
		$${dir}/bin/plugin -install mobz/elasticsearch-head ; \
  fi
	open http://localhost:9200/_plugin/head/

# Publish a fake activity using the API
test-publish :
	coffee lib/publish 1 localhost:3000
