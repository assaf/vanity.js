default :
	cd server && mocha -R list 

setup :
	cd server && npm install
