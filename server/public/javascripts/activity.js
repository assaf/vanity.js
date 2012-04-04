Vanity = {};

// Create a new object for manipulating activity stream.
//
// selector   - Selects OL element to render into
Vanity.Activity = function(selector) {
  var self = this;

  // Render activities.
  //
  // activities - Array with activities
  // highlight  - True to highlight added activities
  function render(activities, highlight) {
    // Top verbs plus 'other'.
    var verbs = topVerbs(activities);

    var selection = d3.select(selector)
      .selectAll("li")
      .data(filterVerbs(activities), function(activity) { return activity.id });
    var li = selection.enter().append("li");

    li.html(function(activity) {
        return activity.html.replace(/(<time.*>).*(<\/time>)/, function(_, head, tail) {
          var date = Date.create(activity.published)
            .format("{Weekday}, {Mon} {d} {h}:{mm} {TT}");
          return head + date + tail;
        })
      });
    li.selectAll("div")
      .append("span").attr("class", "color");
    if (highlight)
      li.attr("class", "highlight").transition()
        .delay(1).attr("class", "");
    selection.exit().remove();
    // Set the color of each activity based on its verb.
    selection.select(".color")
      .style("background-color", function(d) { return verbColor(verbs, d.verb); })
    selection.order();

    renderVerbs(verbs);
  }


  // -- Verbs --
  
  // How many verbs you can show/hide.
  var TOP_VERBS = 10;
  // Color scale - each verb gets its own distinct color.
  var VERB_COLORS = d3.scale.category20c();

  // Keep track of which verbs are showing.
  var verbsShowing = {};


  // Returns a group with the top verbs.
  //
  // activities - All activities
  // count      - How many verbs to show
  //
  // Returns a list of top verbs plus 'other'
  function topVerbs(activities, count) {
    var counts = {},
        list = [],
        top;
    for (var i in activities) {
      var verb = activities[i].verb;
      counts[verb] = (counts[verb] || 0) + 1;
    }
    for (key in counts)
      list.push({ key: key, values: counts[key] });
    top = list.sort(function(a, b) { return b.values - a.values })
      .slice(0, count)
      .map(function(verb) { return verb.key })
      .concat("other");

    // Make sure all verbs are showing by default.
    verbsShowing = top.reduce(function(showing, verb) {
      showing[verb.key] = verbsShowing[verb];
      if (showing[verb] == undefined)
        showing[verb] = true;
      return showing;
    }, {});

    return top;
  }

  // Return color for a verb.
  //
  // verbs - Top verbs, order of which determines color
  // verb  - The verb you're looking to color
  //
  // Returns color suitable for styling an element (rgba).
  function verbColor(verbs, verb) {
    var index = verbs.indexOf(verb),
        color = (index >= 0) ? VERB_COLORS(index) : "#ccc",
        rgb = d3.rgb(color);
    return "rgba(" + rgb.r + "," + rgb.g + "," + rgb.b + ",0.5)"
  }

  // Filters and returns only activities that should show based on selected
  // filter.
  function filterVerbs(activities) {
    return activities.filter(function(activity) {
      var showing = verbsShowing[activity.verb];
      if (showing == undefined)
        showing = verbsShowing["other"];
      return showing;
    })
  }

  // Renders the verb selector: shows the msot popular verbs with option to
  // show/hide each one.
  function renderVerbs(verbs) {
    // For each new verb we add an LI and inside a link to show/hide and a span
    // to show the color-coded verb name.
    var list = d3.select("#verbs"),
        selection = list.selectAll("li").data(verbs),
        li = selection.enter().append("li");
    li.append("a")
      .attr("class", "show")
      .on("click", function(verb) {
        d3.event.stopPropagation();
        // If the class is "show", we're showing the verb. Flip class to hide
        // and turn verbsShowing off.
        if (this.className == "show") {
          this.className = "hide";
          verbsShowing[verb] = false;
        } else {
          this.className = "show";
          verbsShowing[verb] = true;
        }
        // Update all activities accordingly.
        renderActivities();
        return false;
      });
    li.append("span")
      .text(String)
      .style("background-color", function(verb) { return verbColor(verbs, verb) });
    selection.exit().remove();
  }


  self.render = render;
  return self;
}
