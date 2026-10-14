program embed_demo;

{$MODE OBJFPC}{$H+}

uses
  SysUtils,
  pascak_embed;

var
  Engine: TPascakEmbed;
  R: TPascakResult;
begin
  Writeln('=== Pascak Embed Demo ===');
  Writeln;

  Engine := TPascakEmbed.Create(ExpandFileName('~/pascak_noASTnet'));
  try
    Writeln('Binary exists : ', Engine.BinaryExists);
    Writeln;

    // Config
    Engine.SetExecPolicy('allow-all');
    Engine.SetMemoryQuota(128);
    Engine.SetTimeout(30000);
    Engine.SetDevMode(True);
    Engine.SetEnv('MY_VAR', 'hello from host');
    Writeln('Parent MY_VAR = [', GetEnvironmentVariable('MY_VAR'), ']');
    
    // Test 1: simple arithmetic
    Writeln('--- Test 1: simple arithmetic ---');
    R := Engine.ExecuteString('begin println(2 + 2); end.');
    Writeln('Exit: ', R.ExitCode);
    Writeln('Stdout: ', Trim(R.Stdout));
    Writeln('Duration: ', R.DurationMs, 'ms');
    Writeln;
    

    // Test 2: env var read
    Writeln('--- Test 2: read env var ---');
    R := Engine.ExecuteString(
      'begin'#10 +
      '  var v := sys.env("MY_VAR");'#10 +
      '  println("Host says: ", v);'#10 +
      'end.');
    Writeln('Exit: ', R.ExitCode);
    Writeln('Stdout: ', Trim(R.Stdout));
    Writeln;

    // Test 3: error handling
    Writeln('--- Test 3: error handling ---');
    R := Engine.ExecuteString('begin undefined_function(); end.');
    Writeln('Exit: ', R.ExitCode);
    Writeln('Stderr len: ', Length(R.Stderr));
    Writeln;

  finally
    Engine.Free;
  end;

  Writeln('=== Done ===');
end.
ENDOFDEMO
echo "OK — embed_demo.pas created"