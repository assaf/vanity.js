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
	coffee lib/fake_it 1000

send :
	curl http://localhost:3000/v1/activity -H "Content-Type: application/json" -d \
		'{ "actor": { "displayName": "Assaf" }, "verb": "posted" }'


# UI for ElasticSearch
es-view :
	dir=/usr/local/Cellar/elasticsearch/* ;\
	if [[ ! -f $${dir}/plugins/head/index.html ]] ; then \
		echo "Installing ElasticSearch head ..." ; \
		$${dir}/bin/plugin -install mobz/elasticsearch-head ; \
  fi
	open http://localhost:9200/_plugin/head/

