// Contoh: fetch 4 URL secara paralel via worker pool
var urls := [
  "https://example.com",
  "https://httpbin.org/get",
  "https://1.1.1.1",
  "https://example.org"
];

var counter := 0;
var totalSize := 0;

function onResult(res) begin
  counter := counter + 1;
  if res.hasKey("error") then
    println("[", counter, "] ERROR: ", res.error)
  else begin
    totalSize := totalSize + len(res.body);
    println("[", counter, "] ", res.status, " — ", len(res.body), " bytes");
  end
  
  if counter == 4 then
    println("Total fetched: ", totalSize, " bytes")
end;

begin
  println("Fetching ", len(urls), " URLs in parallel...");
  
  var i := 0;
  while i < len(urls) do
  begin
    http.getAsync(urls[i], onResult);
    i := i + 1;
  end
  
  // Script berakhir, event loop akan menunggu callback
end.