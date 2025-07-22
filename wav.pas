{$mode objfpc}{$H+}
program TxtToWav;

uses
  SysUtils, Classes, Math;

const
  SAMPLE_RATE = 44100;
  BITS_PER_SAMPLE = 16;
  channels = 1;
  NOTE_DURATION_SEC = 0.3;
  PAUSE_DURATION_SEC = 0.05;
  VOLUME = 0.3;

type
  TNoteArray = array of Integer;

function MidiToFreq(midi: Integer): Double;
begin
  MidiToFreq := 440.0 * Power(2.0, (midi - 69) / 12.0);
end;

procedure AppendSamples(var buffer: TMemoryStream; notes: TNoteArray; duration: Double);
var
  i, j, sampleCount: Integer;
  t, sample, freq: Double;
  value: SmallInt;
begin
  sampleCount := Round(SAMPLE_RATE * duration);
  for i := 0 to sampleCount - 1 do
  begin
    t := i / SAMPLE_RATE;
    sample := 0;
    for j := 0 to High(notes) do
    begin
      freq := MidiToFreq(notes[j]);
      sample := sample + Sin(2 * Pi * freq * t);
    end;
    sample := (sample / Length(notes)) * VOLUME;
    value := Round(sample * High(SmallInt));
    buffer.Write(value, SizeOf(value));
  end;
end;

procedure AppendSilence(var buffer: TMemoryStream; duration: Double);
var
  i, sampleCount: Integer;
  zero: SmallInt;
begin
  zero := 0;
  sampleCount := Round(SAMPLE_RATE * duration);
  for i := 0 to sampleCount - 1 do
    buffer.Write(zero, SizeOf(zero));
end;

procedure WriteWavHeader(var f: TFileStream; dataSize: Integer);
var
  chunkSize, sampleRate, byteRate, subchunk2Size: LongInt;
  blockAlign: Word;
  bitsPerSample: Word;
  audioFormat: Word;
  c: Int16;
begin
  c:=channels;
  chunkSize := 36 + dataSize;
  subchunk2Size := dataSize;
  sampleRate := SAMPLE_RATE;
  byteRate := SAMPLE_RATE * channels * BITS_PER_SAMPLE div 8;
  blockAlign := channels * BITS_PER_SAMPLE div 8;
  bitsPerSample := BITS_PER_SAMPLE;
  audioFormat := 1; // PCM

  f.Write(PChar('RIFF')^, 4);
  f.Write(chunkSize, 4);
  f.Write(PChar('WAVE')^, 4);

  f.Write(PChar('fmt ')^, 4);
  f.WriteDWord(16); // Subchunk1Size
  f.Write(audioFormat, 2);
  f.Write(c, 2);
  f.Write(sampleRate, 4);
  f.Write(byteRate, 4);
  f.Write(blockAlign, 2);
  f.Write(bitsPerSample, 2);

  f.Write(PChar('data')^, 4);
  f.Write(subchunk2Size, 4);
end;

function GetChord(c: Char): TNoteArray;
begin
  SetLength(GetChord, 3);
  case c of
    '0': begin GetChord[0]:=60; GetChord[1]:=64; GetChord[2]:=67; end;
    '1': begin GetChord[0]:=62; GetChord[1]:=65; GetChord[2]:=69; end;
    '2': begin GetChord[0]:=64; GetChord[1]:=67; GetChord[2]:=71; end;
    '3': begin GetChord[0]:=65; GetChord[1]:=69; GetChord[2]:=72; end;
    '4': begin GetChord[0]:=67; GetChord[1]:=71; GetChord[2]:=74; end;
    '5': begin GetChord[0]:=69; GetChord[1]:=72; GetChord[2]:=76; end;
    '6': begin GetChord[0]:=71; GetChord[1]:=74; GetChord[2]:=77; end;
    '7': begin GetChord[0]:=72; GetChord[1]:=76; GetChord[2]:=79; end;
    '8': begin GetChord[0]:=74; GetChord[1]:=77; GetChord[2]:=81; end;
    '9': begin GetChord[0]:=76; GetChord[1]:=79; GetChord[2]:=83; end;
    else SetLength(GetChord, 0);
  end;
end;

function GetNote(c: Char): Integer;
begin
  case c of
    'A': GetNote := 69;
    'B': GetNote := 71;
    'C': GetNote := 60;
    'D': GetNote := 62;
    'E': GetNote := 64;
    'F': GetNote := 65;
    'G': GetNote := 67;
    'H': GetNote := 70;
    else  GetNote := -1;
  end;
end;

var
  fname, line, txt, wavname: string;
  ftxt: TextFile;
  c: Char;
  note: Integer;
  buf: TMemoryStream;
  fout: TFileStream;
  chord: TNoteArray;
begin
  Write('Nome do ficheiro de texto: ');
  ReadLn(fname);

  if not FileExists(fname) then
  begin
    WriteLn('Ficheiro não encontrado.');
    Halt;
  end;

  AssignFile(ftxt, fname);
  Reset(ftxt);
  txt := '';
  while not EOF(ftxt) do
  begin
    ReadLn(ftxt, line);
    txt := txt + UpperCase(line);
  end;
  CloseFile(ftxt);

  buf := TMemoryStream.Create;
  try
    for c in txt do
    begin
      if c in ['0'..'9'] then
      begin
        chord := GetChord(c);
        if Length(chord) > 0 then
        begin
          AppendSamples(buf, chord, NOTE_DURATION_SEC);
          AppendSilence(buf, PAUSE_DURATION_SEC);
        end;
      end
      else if c in ['A'..'H'] then
      begin
        note := GetNote(c);
        if note <> -1 then
        begin
          SetLength(chord, 1);
          chord[0] := note;
          AppendSamples(buf, chord, NOTE_DURATION_SEC);
          AppendSilence(buf, PAUSE_DURATION_SEC);
        end;
      end;
    end;

    wavname := ChangeFileExt(fname, '.wav');
    fout := TFileStream.Create(wavname, fmCreate);
    try
      WriteWavHeader(fout, buf.Size);
      buf.Position := 0;
      fout.CopyFrom(buf, buf.Size);
    finally
      fout.Free;
    end;

    WriteLn('✅ WAV gerado: ', wavname);
  finally
    buf.Free;
  end;
end.
