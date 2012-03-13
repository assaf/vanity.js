assert  = require("assert")
Browser = require("zombie")
Poutine = require("poutine")
server  = require("../lib/vanity/dashboard")
Activity = require("../lib/vanity/models/activity")


Browser.site = "localhost:3003"

# http://www.census.gov/genealogy/names/names_files.html

File = require("fs")
lines = File.readFileSync("#{__dirname}/../data/us.male.tab", "utf-8").split(/\n/)
Tree = require("../lib/vanity/name_tree")



# Go through every line, which contains name, frequency and cumulative frequency, and add it to bottom layer of the
# b-tree (leafs).
tree = new Tree()
for line in lines
  continue if line == ""
  [name, freq, cumul] = line.split(/\s+/)
  tree.add parseFloat(cumul), name
find = tree.done()


console.log "2.1 - JAMES"
console.log find(2.1)
console.log "89.939 - WALLY"
console.log find(89.939)
console.log "90.050 - ALONSO"
console.log find(90.050)

process.exit(1)





describe "activity", ->
  browser = new Browser()
  activity_id = null

  before (done)->
    server.listen 3003, done


  # Activity actor.
  describe "actor", ->

    describe "name only", ->
      before (done)->
        Activity.create id: "5678", actor: { displayName: "Assaf" }, (error, doc)->
          activity_id = doc._id
          browser.visit "/activity/#{activity_id}", done
    
      it "should include activity identifier", ->
        assert id = browser.query(".activity").getAttribute("id")
        assert.equal id, "activity-#{activity_id}"

      it "should show actor name", ->
        assert.equal browser.query(".activity .actor .name").innerHTML, "Assaf"

      it "should not show actor image", ->
        assert !browser.query(".activity .actor img")

      it "should not link to actor", ->
        assert !browser.query(".activity .actor a")

    describe "no name", ->

      describe "but id", ->
        before (done)->
          Activity.create id: "5676", (error, doc)->
            activity_id = doc._id
            browser.visit "/activity/#{activity_id}", done

        it "should make name up from ID", ->
          assert.equal browser.query(".activity .actor .name").textContent, "John Smith"

      #describe "or id"
      
    describe "image", ->
      before (done)->
        Activity.create id: "5677", actor: { displayName: "Assaf", image: { url: "http://awe.sm/5hWp5" } }, (error, doc)->
          activity_id = doc._id
          browser.visit "/activity/#{activity_id}", done
    
      it "should include avatar", ->
        assert.equal browser.query(".activity .actor img.avatar").getAttribute("src"), "http://awe.sm/5hWp5"

      it "should place avatar before display name", ->
        assert browser.query(".activity .actor img.avatar + span.name")

    describe "url", ->
      before (done)->
        Activity.create id: "5679", actor: { displayName: "Assaf", url: "http://labnotes.org", image: { url: "http://awe.sm/5hWp5" } }, (error, doc)->
          activity_id = doc._id
          browser.visit "/activity/#{activity_id}", done

      it "should link to actor", ->
        assert.equal browser.query(".activity .actor a").getAttribute("href"), "http://labnotes.org"

      it "should place display name inside link", ->
        assert.equal browser.query(".activity .actor a .name").textContent, "Assaf"

      it "should place profile photo inside link", ->
        assert.equal browser.query(".activity .actor img.avatar").getAttribute("src"), "http://awe.sm/5hWp5"


  after ->
    Poutine.connect().driver (error, db)->
      db.dropCollection(Activity.collection_name)
