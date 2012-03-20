# Run all tests
default :
	mocha -R list 

# Setup everything
setup :
	npm install

# UI for ElasticSearch
es-view :
	if [[ ! -d /usr/local/Cellar/elasticsearch/0.19.0/plugins/head/ ]] ; then \
		echo "Installing ElasticSearch head" ; \
		/usr/local/Cellar/elasticsearch/*/bin/plugin -install mobz/elasticsearch-head ; \
  fi
	open http://localhost:9200/_plugin/head/
