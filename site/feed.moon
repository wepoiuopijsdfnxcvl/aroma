require "date"

release = (t) ->
  title = "version "..t.version
  desc = if t.changes
    leading = t.changes\match"^(%s*)" or ""
    simple_date = t.date\fmt "%B %d %Y"
    table.concat {
      leading .. "## ".. title .. " - " .. simple_date
      "\n\n"
      t.changes
    }
  else
    ""
  {
    title: title
    link: "http://leafo.net/aroma/#v" .. t.version
    date: t.date
    description: desc
  }

return {
  format: "markdown"
  title: "Aroma Changelog"
  link: "http://leafo.net/aroma/"
  description: "Aroma is a game engine for Native Client"

  release {
    version: "0.0.1"
    date: date 2012, 5, 13, 18, 53
    changes: [[
      Initial Release
    ]]
  }
}
