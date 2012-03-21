# Run all tests
default :
	mocha -R list 


# Setup everything
setup :
	npm install


# Populates ElasticSearch with fake data
fake :
	coffee lib/fake_it


# UI for ElasticSearch
es-view :
	dir=/usr/local/Cellar/elasticsearch/* ;\
	if [[ ! -f $${dir}/plugins/head/index.html ]] ; then \
		echo "Installing ElasticSearch head ..." ; \
		$${dir}/bin/plugin -install mobz/elasticsearch-head ; \
  fi
	open http://localhost:9200/_plugin/head/
