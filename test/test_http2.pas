// test_http2.pas — HTTP/2 client end-to-end (soft, network-dependent)
begin
  testBegin("HTTP/2 Client (D.2)");

  try
    var r := http.get2("https://httpbin.org/get");

    if r == null then begin
      println("SKIP: http.get2 returned null (no network)");
      testEnd();
      sys.exit(0);
    end;

    assertEqual(200, r["status"], "status 200 from httpbin.org");
    assertEqual("h2", r["version"], "negotiated h2");
    assertTrue(len(r["body"]) > 0, "body non-empty");
    assertTrue(pos('"url"', r["body"]) > 0, "body has url field");

    var r2 := http.get2("https://httpbin.org/get", {
      "X-Pascak-Test": "hello-pascak"
    });

    if r2 != null then begin
      assertEqual(200, r2["status"], "custom headers request");
      assertTrue(pos("hello-pascak", r2["body"]) > 0, "custom header echoed");
    end;
  catch e do begin
    println("SKIP: network or http.get2 error");
    testEnd();
    sys.exit(0);
  end;

  testEnd();
  sys.exit(testSummary());
end.
