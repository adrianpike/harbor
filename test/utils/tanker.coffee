# My naming can be a little overclever. Sorry not sorry.

console.log 'Tanker up!'
console.log "PORT:#{process.env.PORT}"

if process.argv[2] is 'crash'
  console.log 'Crashing!'
else
  console.log 'Floating!'
  setTimeout ->
    console.log 'Now sinking.'
  , 1000
