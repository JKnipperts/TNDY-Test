 uses misc,textmode;

 const
 title          : string = 'TNDY / TLPT Test utility v0.52 (c) 2019-2020 by Jan Knipperts';
 footer         : string = 'F1 = Function test, ESC = quit to DOS';
 footer1        : string = '';
 tandyFreq      = 3579545;
 tandyDivider   = tandyFreq/32;
 tandyIntDivider= round(tandyDivider);
 minfreq        = 110;
 maxfreq        = 11000;
 delayval       = 80;


 type
    square_generator = record
      vol       : byte;
      freq      : integer;
      end;

    noise_generator = record
      vol       : byte;
      freq      : integer;
      ntype     : byte;
      end;

 var
    p            : pointer;
    lpt,
    keyboardmode : boolean;
    xp,yp,
    select,
    win,
    ps,adjust    : byte;
    key          : char;
    t1,t2,t3     : square_generator;
    t4           : noise_generator;
    s,
    fbutton,
    mbutton      : string;
    tandyport    : word;
    data,
    status,
    ctrl         : word;
    z,i          : word;


Procedure Button(x,y : byte; name : string; pressed : boolean);
 var col,c : byte;
begin
  if vidseg = $B800 then
  begin
    if pressed then col := 1 else col := 0;

    fastwrite(x,y,0,7,name);
    c := 1;
    while (name[c] = ' ') and (c <= length(name)) do inc(c);
    putchar(x+(c-1),y,name[c],4,7);

    for c := x+1 to x+length(name) do fastwrite(c,y+1,col,1, 'ß');
    fastwrite(x+length(name),y,col,1, 'Ü');
  end
  else
  begin
     fastwrite(x,y,0,7,name);
     c := 1;
     while (name[c] = ' ') and (c <= length(name)) do inc(c);
     putchar(x+(c-1),y,name[c],0,0);
     if pressed then
     begin
      for c := x to x+length(name) do AttrMDA(c,y,false,false,true);
     end;

  end;

end;




Procedure LPT_Send(b : byte);
assembler;
asm
  mov al,b
  mov dx,data
  out dx,al

  mov al,12
  mov dx,ctrl
  out dx,al

  mov dx,status
  mov cx,$18

  @@1:
  in al,dx
  test al,$40
  loopnz @@1

  inc cx

  @@2:
  in al,dx
  test al,$40
  loopnz @@2

  mov dx,ctrl
  mov al,9
  out dx,al
end;


procedure tandyLPTSound(voice:byte; tone:word; level:byte);
begin
  if tone > 0 then tone := tandyIntDivider div tone;
  LPT_Send($80 or (voice*$20) or (tone and $0F));
  LPT_Send(tone shr 4);
  LPT_Send($90 or (voice*$20) or (level and $0F));
end;

procedure tandyLPTNoise(divider, feedback, level:byte);
var noisebyte : byte;
begin
  asm
    xor  al,al
    mov  al,11100000b
    mov  noisebyte,al
   end;

   if feedback > 0 then noisebyte := noisebyte or 4;
   noisebyte := noisebyte or divider;
   LPT_Send(noisebyte);

   asm
    xor  al,al
    mov  al,11110000b
    or   al,level
    mov  noisebyte,al
   end;
   LPT_Send(noisebyte);
end;


Procedure MuteTandyLPT;
begin
 asm
  mov dx,ctrl
  mov al,00000100b        {set bit 2, reset}
  out dx,al
 end;
 xdelay(150);
 LPT_Send($9F);
 LPT_Send($BF);
 LPT_Send($DF);
 LPT_Send($FF);
end;

Procedure MuteTandy;
assembler;
 asm
  mov dx,TandyPort
  mov al,$9F
  out dx,al
  mov al,$BF
  out dx,al
  mov al,$DF
  out dx,al
  mov al,$FF
  out dx,al
 end;





Function Init_PP(LPTnum : byte) : Boolean;
begin
 tandyport := LPTnum;
 data := memw[$40:6+LPTnum*2];

 {ECP code fehlt!}

 if data = 0 then
 begin
  lpt := false;
  status := 0;
  ctrl := 0;
 end
 else
 begin
  lpt := true;
  status := data + 1;
  ctrl := data + 2;
 end;

 Init_PP := lpt;
end;

procedure tandySound(voice:byte; tone:word; level:byte);
begin
   if tone > 0 then tone := tandyIntDivider div tone;
asm
	mov  dx,TandyPort
	mov  cl,voice
	mov  al,$10
	shl  al,cl
	and  al,$60
	or   al,$80
	mov  ch,al { save channel for level set }
	mov  bx,tone
	mov  ah,bl
	and  ah,$0F
	or   al,ah
	out  dx,al
	mov  cl,4
	shr  bx,cl
	mov  al,bl
	out  dx,al
	mov  al,level
	and  al,$0F
	or   al,ch
	or   al,$10
	out  dx,al
end;
end;

procedure tandyNoised(divider, feedback, level:byte); assembler;
asm
        mov  ax,bx

        mov  dx,TandyPort
        xor  al,al
        mov  al,11100000b
        cmp feedback,0
        je  @SkipFeedback
        or   al,4

        @SkipFeedback:
        or   al,divider
        out  dx,al


        xor  al,al
        mov  al,11110000b
        or   al,level
	out  dx,al
end;



Procedure PlaySquarewave;
begin
  if lpt then
  begin
   if (t1.freq >= minfreq) then
   begin
    tandyLPTSound(0,t1.freq,t1.vol);
   end
   else
    LPT_Send($9F);

   if (t2.freq >= minfreq) then
   begin
    tandyLPTSound(1,t2.freq,t2.vol);
   end
   else
    LPT_Send($BF);

   if (t3.freq >= minfreq) then
   begin
    tandyLPTSound(2,t3.freq,t3.vol);
   end
   else
    LPT_Send($DF);

  end
  else
  begin

   if (t1.freq >= minfreq) then
   begin
    tandySound(0,t1.freq,t1.vol);
   end
   else
    port[TandyPort] := $9F;

   if (t2.freq >= minfreq) then
   begin
    tandySound(1,t2.freq,t2.vol);
   end
   else
    port[TandyPort] := $BF;

   if (t3.freq >= minfreq) then
   begin
    tandySound(2,t3.freq,t3.vol);
   end
   else
    port[TandyPort] := $DF;

  end;
end;

Procedure PlayNoise;
begin
  if lpt then
  begin
   tandyLPTNoise(t4.freq,t4.ntype,t4.vol);
  end
  else
  begin
   tandyNoised(t4.freq,t4.ntype,t4.vol);
  end;
end;


Procedure Mute;
begin
 if lpt then
 begin
   MuteTandyLPT;
   tandyLPTNoise(0,0,15);
 end
 else
 begin
   MuteTandy;
   tandyNoised(0,0,15);
 end;
end;


Procedure InitTandySound;      {Reset the sound chip}
begin
  if lpt then
  begin
    LPT_Send(1);
    xdelay(10);
    LPT_Send(9);
    xdelay(10);
  end
  else
  begin
    port[TandyPort] := 1;
    xdelay(10);
    port[TandyPort] := 9;
    xdelay(10);
  end;
  Mute;
  xdelay(100);
  Mute;
end;




 Procedure DrawSelector(xp,yp : byte; s : string);
 begin
  if not keyboardmode then
  begin
   putchar(xp+9,yp,#24,0,7);
   putchar(xp+10,yp,#25,0,7);
  end;
  fastwrite(xp,yp,15,1,'         ');
  fastwrite(xp+(4-(length(s) div 2)),yp,15,1,s);
 end;

 Procedure Mark(x,y,l : byte);
 var c : byte;
 begin
    for c := x to x+(l-1) do
    begin
      if VidSeg = $B800 then changeattr(c,y,atr(14,4,false))
      else
      AttrMDA(c,y,true,true,true);
    end;
 end;

 Procedure UnMark(x,y,l : byte);
 var c : byte;
 begin
    for c := x to x+(l-1) do
    begin
      if VidSeg = $B800 then changeattr(c,y,atr(15,1,false))
      else
      AttrMDA(c,y,false,false,false);
    end;
 end;


 Procedure Wait_for_Mousebutton;
 begin
     repeat
         Mouse_Read;
         while iskeypressed do getkey;
     until mouse.b = 0;
     key := #0;
     {selectitem(select);}
 end;


 Procedure MarkOption(opt : byte);
 begin

  if keyboardmode then
  begin
   UnMark(40,4,4);
   UnMark(21,11,8);
   UnMark(21,12,8);
   UnMark(21,15,8);
   UnMark(21,16,8);
   UnMark(21,19,8);
   UnMark(21,20,8);
   UnMark(57,10,8);
   UnMark(57,11,8);
   UnMark(57,12,8);
  case opt of
   0: Mark(40,4,4);
   1: Mark(21,11,8);
   2: Mark(21,12,8);
   3: Mark(21,15,8);
   4: Mark(21,16,8);
   5: Mark(21,19,8);
   6: Mark(21,20,8);
   7: Mark(57,10,8);
   8: Mark(57,11,8);
   9: Mark(57,12,8);
  end;
  end;
 end;

 Procedure Function_Test;
 begin
       mouse_hide;
       move(ptr(vidseg,0)^,p^,4000);   {Move actual screen to buffer}
       writeto(ptr(vidseg,0));     {write to video mem}
       ShadowScreen;                  {makes the screen black and white}
       window(10,3,70,22,14,1,true);
       centeredtext(3,15,' SN76489 chip function test: ');
       centeredtext(21,15,'Testing port: '+hexw(tandyport));

       centeredtext(5,15,'1. Testing sound generators');
       MuteTandy;
       centeredtext(6,14,'Tone generator 1: Playing C-4 (262 Hz)');
       tandySound(0,262,0);
       xdelay(500);
       MuteTandy;
       centeredtext(7,14,'Tone generator 2: Playing D-4 (294 Hz)');
       tandySound(1,294,0);
       xdelay(500);
       MuteTandy;
       centeredtext(8,14,'Tone generator 3: Playing E-4 (330 Hz)');
       tandySound(2,330,0);
       xdelay(500);
       MuteTandy;
       centeredtext(10,15,'2. Testing noise generator');
       centeredtext(11,14,'Playing white noise at 6991 Hz');

       tandyNoised(0, 1, 0);
       xdelay(500);
       tandyNoised(0, 1, 15);
       centeredtext(12,14,'Playing white noise at 3496 Hz');

       tandyNoised(1, 1, 0);
       xdelay(500);
       tandyNoised(0, 1, 15);
       centeredtext(13,14,'Playing white noise at 1748 Hz');

       tandyNoised(2, 1, 0);
       xdelay(500);
       tandyNoised(0, 1, 15);
       centeredtext(14,14,'Playing periodic noise at 6991 Hz');

       tandyNoised(0, 0, 0);
       xdelay(500);
       MuteTandy;
       centeredtext(15,14,'Playing periodic noise at 3496 Hz');

       tandyNoised(1, 0, 0);
       xdelay(500);
       MuteTandy;
       centeredtext(16,14,'Playing periodic noise at 1748 Hz');

       tandyNoised(2, 0, 0);
       xdelay(500);
       MuteTandy;
       centeredtext(18,15,'Press any key to continue...');
       mouse_show;
       while iskeypressed do getkey;

       repeat
       if keyboardmode = false then Mouse_Read;
       until (iskeypressed = true) or
                    (mouse.b = 1);
       while iskeypressed do getkey;
       key := #0;
       mouse_hide;
       ViewBuffer(p);               {show buffer}
       mouse_show;
 end;




 Procedure Control_Options;
 begin

      if key = #59 then
      begin
       Function_Test;
      end;


      if (keyboardmode = true) then
      begin

       if (key = #77) then
       begin
        if (win = 1) and (select < 7) then inc(select);
       end;
       if (key = #75) then
       begin
        if (win = 1) and (select > 0) then dec(select);
       end;

       if (key = #72) then
       begin
        if select = 0 then
        begin
         select := 9;
         win := 3;
        end
        else
        begin
         dec(select);
         if select > 6 then win := 3 else win := 2;
        end;

         MarkOption(select);
         ViewBuffer(p);
         while iskeypressed do getkey;
         key := #0;
       end;


       if (key = #80) then
       begin
        if select = 9 then
        begin
         select := 0;
         win := 1;
        end
        else
        begin
         inc(select);
         if select >= 7 then win := 3 else win := 2;
        end;

         MarkOption(select);
         ViewBuffer(p);
         while iskeypressed do getkey;
         key := #0;
       end;


       if key = #9 then
       begin
         if win = 3 then win := 1
         else inc(win);

         if win = 1 then
         begin
          select := 0;
         end;

         if win = 2 then
         begin
          select := 1;
         end;

         if win = 3 then
         begin
          select := 7;
         end;

         MarkOption(select);
         ViewBuffer(p);
         while iskeypressed do getkey;
         key := #0;
      end;
      end;

      {Ports}
      {'0C0 0E0 1E0 2C0 2E0  LPT1 LPT2 LPT3'}

      if ((mouse.b = 1) and ((xp = 47 ) and (yp = 4))) or
         ((keyboardmode = true) and (select = 0) and
         ((key = '+') or(key = #32) or (key = #13)))  then
      begin
       fastwrite(26,5,12,1,'                             ');
       Mute;
       lpt := false;
       if ps < 7 then inc(ps) else ps := 0;

       case ps of
        0: begin
            tandyport := $0C0;
            s := '0C0h';
           end;
        1: begin
            tandyport := $0E0;
            s := '0E0h';
           end;
        2: begin
            tandyport := $1E0;
            s := '1E0h';
           end;
        3: begin
            tandyport := $2C0;
            s := '2C0h';
           end;
        4: begin
            tandyport := $2E0;
            s := '2E0h';
           end;
        5: begin
            tandyport := 1;
            s := 'LPT1';
            if not init_PP(1) then
            begin
             fastwrite(26,5,12,1,'Parallel port LPT1 not found!');
             Tandyport := $0C0;
            end;
           end;
        6: begin
            tandyport := 2;
            s := 'LPT2';
            if not init_PP(2) then
            begin
             fastwrite(26,5,12,1,'Parallel port LPT2 not found!');
             Tandyport := $0C0;
            end;
           end;
        7: begin
            tandyport := 3;
            s := 'LPT3';
            if not init_PP(3) then
            begin
             fastwrite(26,5,12,1,'Parallel port LPT3 not found!');
             Tandyport := $0C0;
            end;
           end;
           end;

       mouse_hide;
       DrawSelector(38,4,s);
       MarkOption(select);
       ViewBuffer(p);
       if not keyboardmode then mouse_show;
       InitTandySound;
       PlaySquarewave;

      end;

      if ((mouse.b = 1) and ((xp = 48 ) and (yp = 4)) or
         ((keyboardmode = true) and (select = 0) and
         (key = '-')))  then
      begin
        fastwrite(26,5,12,1,'                             ');
        Mute;
        lpt := false;
        if ps > 0 then dec(ps) else ps := 7;

        case ps of
        0: begin
            tandyport := $0C0;
            s := '0C0h';
           end;
        1: begin
            tandyport := $0E0;
            s := '0E0h';
           end;
        2: begin
            tandyport := $1E0;
            s := '1E0h';
           end;
        3: begin
            tandyport := $2C0;
            s := '2C0h';
           end;
        4: begin
            tandyport := $2E0;
            s := '2E0h';
           end;
        5: begin
            tandyport := 1;
            s := 'LPT1';
            if not init_PP(1) then
            begin
             fastwrite(26,5,12,1,'Parallel port LPT1 not found!');
             Tandyport := $0C0;
            end;
           end;
        6: begin
            tandyport := 2;
            s := 'LPT2';
            if not init_PP(2) then
            begin
              fastwrite(26,5,12,1,'Parallel port LPT2 not found!');
              Tandyport := $0C0;
            end;
           end;
        7: begin
            tandyport := 3;
            s := 'LPT3';
            if not init_PP(3) then
            begin
             fastwrite(26,5,12,1,'Parallel port LPT3 not found!');
             Tandyport := $0C0;
            end;
           end;
           end;

       mouse_hide;
       DrawSelector(38,4,s);
       MarkOption(select);
       ViewBuffer(p);
       if not keyboardmode then mouse_show;
       InitTandySound;
       PlaySquarewave;

      end;






       {TG1 freq}
      if ((mouse.b = 1) and ((xp = 30 ) and (yp = 11)) or
         ((keyboardmode = true) and (select = 1) and
         ((key = '+') or(key = #32) or (key = #13))))  then
      begin
        inc(t1.freq,adjust);
        if t1.freq < minfreq then t1.freq := minfreq;
        if t1.freq > maxfreq then t1.freq := maxfreq;
        str(t1.freq,s);
        mouse_hide;
        DrawSelector(21,11,s+' Hz');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then
        begin
         mouse_show;
         xdelay(delayval);
        end;
        PlaySquarewave;
      end;

      if ((mouse.b = 1) and ((xp = 31 ) and (yp = 11)) or
         ((keyboardmode = true) and (select = 1) and
         ((key = '-'))))  then
      begin
        if (t1.freq-adjust) > minfreq then
        begin
         dec(t1.freq,adjust);
         str(t1.freq,s);
         s := s + ' Hz';
        end
        else
        begin
         s := 'OFF';
         t1.freq := 0;
        end;

        mouse_hide;
        DrawSelector(21,11,s);
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then
        begin
         mouse_show;
         xdelay(delayval);
        end;
        PlaySquarewave;
      end;

      {TG1 vol}
      if ((mouse.b = 1) and ((xp = 31 ) and (yp = 12)) or
         ((keyboardmode = true) and (select = 2) and
         ((key = '-'))))  then
      begin
        inc(t1.vol);
        if t1.vol > 15 then t1.vol := 15;
        str(100-((t1.vol / 15)*100):3:0,s);
        mouse_hide;
        DrawSelector(21,12,s+'%');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then mouse_show;
        PlaySquarewave;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and ((xp = 30 ) and (yp = 12)) or
         ((keyboardmode = true) and (select = 2) and
         ((key = '+') or(key = #32) or (key = #13))))  then
      begin
        if t1.vol > 0 then dec(t1.vol);
        str(100-((t1.vol / 15)*100):3:0,s);
        mouse_hide;
        DrawSelector(21,12,s+'%');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then mouse_show;
        PlaySquarewave;
        Wait_for_Mousebutton;
      end;

      {TG2 freq}
      if ((mouse.b = 1) and ((xp = 30 ) and (yp = 15)) or
         ((keyboardmode = true) and (select = 3) and
         ((key = '+') or(key = #32) or (key = #13))))  then
      begin
        inc(t2.freq,adjust);
        if t2.freq < minfreq then t2.freq := minfreq;
        if t2.freq > maxfreq then t2.freq := maxfreq;
        str(t2.freq,s);
        mouse_hide;
        DrawSelector(21,15,s+' Hz');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then
        begin
         mouse_show;
         xdelay(delayval);
        end;
        PlaySquarewave;
      end;

      if ((mouse.b = 1) and ((xp = 31 ) and (yp = 15)) or
         ((keyboardmode = true) and (select = 3) and
         ((key = '-'))))  then
      begin
        if (t2.freq-adjust) > minfreq then
        begin
         dec(t2.freq,adjust);
         str(t2.freq,s);
         s := s + ' Hz';
        end
        else
        begin
         s := 'OFF';
         t2.freq := 0;
        end;

        mouse_hide;
        DrawSelector(21,15,s);
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then
        begin
         mouse_show;
         xdelay(delayval);
        end;
        PlaySquarewave;
      end;

      {TG2 vol}
      if ((mouse.b = 1) and ((xp = 31 ) and (yp = 16)) or
         ((keyboardmode = true) and (select = 4) and
         ((key = '-'))))  then
      begin
        inc(t2.vol);
        if t2.vol > 15 then t2.vol := 15;
        str(100-((t2.vol / 15)*100):3:0,s);
        mouse_hide;
        DrawSelector(21,16,s+'%');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then mouse_show;;
        PlaySquarewave;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and ((xp = 30 ) and (yp = 16)) or
         ((keyboardmode = true) and (select = 4) and
         ((key = '+') or(key = #32) or (key = #13))))  then
      begin
        if t2.vol > 0 then dec(t2.vol);
        str(100-((t2.vol / 15)*100):3:0,s);
        mouse_hide;
        DrawSelector(21,16,s+'%');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then mouse_show;;
        PlaySquarewave;
        Wait_for_Mousebutton;
      end;


      {TG3 freq}
      if ((mouse.b = 1) and ((xp = 30 ) and (yp = 19)) or
         ((keyboardmode = true) and (select = 5) and
         ((key = '+') or(key = #32) or (key = #13))))  then
      begin
        inc(t3.freq,adjust);
        if t3.freq < minfreq then t3.freq := minfreq;
        if t3.freq > maxfreq then t3.freq := maxfreq;
        str(t3.freq,s);
        mouse_hide;
        DrawSelector(21,19,s+' Hz');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then
        begin
         mouse_show;
         xdelay(delayval);
        end;
        PlaySquarewave;
      end;

      if ((mouse.b = 1) and ((xp = 31 ) and (yp = 19)) or
         ((keyboardmode = true) and (select = 5) and
         ((key = '-'))))  then
      begin
        if (t3.freq-adjust) > minfreq then
        begin
         dec(t3.freq,adjust);
         str(t3.freq,s);
         s := s + ' Hz';
        end
        else
        begin
         s := 'OFF';
         t3.freq := 0;
        end;


        mouse_hide;
        DrawSelector(21,19,s);
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then
        begin
         mouse_show;
         xdelay(delayval);
        end;
        PlaySquarewave;
      end;

      {TG3 vol}
      if ((mouse.b = 1) and ((xp = 31 ) and (yp = 20)) or
         ((keyboardmode = true) and (select = 6) and
         ((key = '-'))))  then
      begin
        inc(t3.vol);
        if t3.vol > 15 then t3.vol := 15;
        str(100-((t3.vol / 15)*100):3:0,s);
        mouse_hide;
        DrawSelector(21,20,s+'%');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then mouse_show;
        PlaySquarewave;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and ((xp = 30 ) and (yp = 20)) or
         ((keyboardmode = true) and (select = 6) and
         ((key = '+') or(key = #32) or (key = #13))))  then
      begin
        if t3.vol > 0 then dec(t3.vol);
        str(100-((t3.vol / 15)*100):3:0,s);
        mouse_hide;
        DrawSelector(21,20,s+'%');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then mouse_show;;
        PlaySquarewave;
        Wait_for_Mousebutton;
      end;


      if ((mouse.b = 1) and ((xp = 67 ) and (yp = 10)) or
         ((keyboardmode = true) and (select = 7) and
         ((key = '-'))))  then

      begin
       mouse_hide;
       if t4.freq < 2 then inc(t4.freq);
       case t4.freq of
       0 : s := '6991 Hz';
       1 : s := '3496 Hz';
       2 : s := '1748 Hz';
       end;
       DrawSelector(57,10,s);
       MarkOption(select);
       ViewBuffer(p);
       if not keyboardmode then mouse_show;;
       PlayNoise;
       Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and ((xp = 66 ) and (yp = 10)) or
         ((keyboardmode = true) and (select = 7) and
         ((key = '+') or(key = #32) or (key = #13))))  then

      begin
       mouse_hide;
       if t4.freq > 0 then dec(t4.freq);
       case t4.freq of
       0 : s := '6991 Hz';
       1 : s := '3496 Hz';
       2 : s := '1748 Hz';
       end;
       DrawSelector(57,10,s);
       MarkOption(select);
       ViewBuffer(p);
       if not keyboardmode then mouse_show;;
       PlayNoise;
       Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and ((xp = 67 ) and (yp = 11)) or
         ((keyboardmode = true) and (select = 8) and
         ((key = '-'))))  then
      begin
        inc(t4.vol);
        if t4.vol > 15 then t4.vol := 15;
        str(100-((t4.vol / 15)*100):3:0,s);
        mouse_hide;
        if t4.vol = 15 then DrawSelector(57,11,'OFF') else
        DrawSelector(57,11,s+'%');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then mouse_show;;
        PlayNoise;
        Wait_for_Mousebutton;
      end;


       if ((mouse.b = 1) and ((xp = 66 ) and (yp = 11)) or
         ((keyboardmode = true) and (select = 8) and
         ((key = '+') or(key = #32) or (key = #13))))  then
      begin
        if t4.vol > 0 then dec(t4.vol);
        str(100-((t4.vol / 15)*100):3:0,s);
        mouse_hide;
        DrawSelector(57,11,s+'%');
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then mouse_show;;
        PlayNoise;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and ((xp = 66 ) or (xp = 67) and (yp = 12)) or
         ((keyboardmode = true) and (select = 9) and
         ((key = '+') or (key = '-') or (key = #32) or (key = #13))))  then
     begin

      if t4.ntype = 0 then t4.ntype := 1 else t4.ntype := 0;
      case t4.ntype of
       0: s := 'Periodic';
       1: s := 'White  ';
      end;

       mouse_hide;
       DrawSelector(57,12,s);
       MarkOption(select);
       ViewBuffer(p);
       if not keyboardmode then mouse_show;;
       PlayNoise;
       Wait_for_Mousebutton;

      end;

     if ((mouse.b = 1) and (((xp >= 51 ) and (xp <= 68)) and (yp = 18))) or
         (upcase(key) = 'M') then
     begin
        mouse_hide;
        Button(51,18,mbutton,true);
        ViewBuffer(p);

        if not keyboardmode then
        begin
         mouse_show;
         Wait_for_Mousebutton
        end
        else
        begin
         key := #0;
         while iskeypressed do getkey;
        end;

        Mute;
        t1.freq := 0;
        t2.freq := 0;
        t3.freq := 0;
        t4.vol := 15;
        DrawSelector(21,11,'OFF');
        DrawSelector(21,15,'OFF');
        DrawSelector(21,19,'OFF');
        DrawSelector(57,11,'OFF');
        if keyboardmode then xdelay(300);
        mouse_hide;
        Button(51,18,mbutton,false);
        MarkOption(select);
        ViewBuffer(p);
        if not keyboardmode then mouse_show;
     end;


     if ((mouse.b = 1) and (((xp >= 49 ) and (xp <= 69)) and (yp = 20))) or
         (upcase(key) = 'F') then
     begin

        if adjust = 100 then
        begin
          mouse_hide;
          Button(49,20,fbutton,true);
          MarkOption(select);
          ViewBuffer(p);
          if not keyboardmode then mouse_show;
          Wait_for_Mousebutton;
          key := #0;
          while iskeypressed do getkey;
          adjust := 1;
        end
        else
        begin
          mouse_hide;
          Button(49,20,fbutton,false);
          MarkOption(select);
          ViewBuffer(p);
          if not keyboardmode then mouse_show;
          Wait_for_Mousebutton;
          key := #0;
          while iskeypressed do getkey;
          adjust := 100;
        end;




       end;


 end;


{================= Handle command line options ========================}

Function FindOption(lookup : string) : boolean;
var cnt : byte;
    s   : string;
begin
 FindOption := false;
 for cnt := 1 to paramcount do
 begin
  if length(paramstr(cnt)) > length(lookup) then
  s := copy(uppercase(paramstr(cnt)),1,length(lookup))
  else
  s := uppercase(paramstr(cnt));

  if s = uppercase(lookup) then
  begin
   FindOption := true;
   break;
  end;

 end;
end;






{====================================== Main program ========================}




begin
 lpt := false;
 tandyport := $0C0;
 win     := 1;
 ps      := 0;
 t1.freq := 0;
 t1.vol  := 0;
 t2.freq := 0;
 t2.vol  := 0;
 t3.freq := 07;
 t3.vol  := 0;
 t4.freq := 2;
 t4.vol := 15;
 t4.ntype := 0;
 adjust   := 100;

 VidSeg := Detect_VidSeg;

 if FindOption('/MDA') then
 begin
  VidSeg := $B000;
 end;
 if FindOption('/COLOR') then
 begin
  VidSeg := $B800;
 end;

 viewseg := VidSeg;
 writeseg := viewseg;

 if vidseg = $B800 then
 begin
  asm
   xor ah,ah
   mov al,3
   int 10h
  end;
 end
 else
 begin
  asm
   xor ah,ah
   mov al,7
   int 10h
  end;
 end;

 writeln('Detecting hardware...');	

 if FindOption('/?') or FindOption('?') then
 begin
  gotoxy(1,1);
  writeln('                      ');
  gotoxy(40-(length(title) div 2),1);
  writeln(title);
  writeln('');
  writeln(' Possible comand line parameters: ');
  writeln('');
  writeln(' /K           - Disables mouse and forces keyboard control ');
  writeln(' /MDA         - Forces mode for monochrome display adapters ');
  writeln(' /COLOR       - Forces mode for color display adapters ');
  writeln(' /TEST <Port> - Performs a quick soundcheck using the given port');
  writeln('');
  halt(0);
 end;

 if (mouse_init = false) or FindOption('/K') then
 begin
  keyboardmode := true;
  fbutton := '(F)ine frequency tuning';
  mbutton := '(M)ute all channels';
 end
 else
 begin
  keyboardmode := false;
  fbutton := 'Fine frequency tuning';
  mbutton := 'Mute all channels';
 end;


 cursor(false);
 getmem(p,4000); {Alloc additional screen buffer}
 fillchar(p^,4000,0);
 writeto(p);
 InitMenuScreen(title);
 Centeredline(25,14,1,footer);

 if FindOption('/TEST') then
 begin
  if FindOption('E0') or
     FindOption('E0h') or
     FindOption('0E0') or
     FindOption('0E0h') then tandyport := $0E0;
  if FindOption('1E0') or FindOption('1E0h') then tandyport := $1E0;
  if FindOption('2C0') or FindOption('2C0h') then tandyport := $2C0;
  if FindOption('2E0') or FindOption('2E0h') then tandyport := $2E0;
  if FindOption('LPT1') then
  begin
    tandyport := 1;
    if not init_PP(1) then
    begin
     clrscr;
     writeto(ptr(viewseg,0));
     freemem(p,4000);
     cursor(true);
     writeln('ERROR: Parallel port LPT1 not found!');
     writeln('');
     halt(1);
    end;
  end;
  if FindOption('LPT2') then
  begin
    tandyport := 2;
    if not init_PP(2) then
    begin
     clrscr;
     writeto(ptr(viewseg,0));
     freemem(p,4000);
     cursor(true);
     writeln('ERROR: Parallel port LPT2 not found!');
     writeln('');
     halt(1);
    end;
  end;
 if FindOption('LPT3') then
  begin
    tandyport := 3;
    if not init_PP(3) then
    begin
     clrscr;
     writeto(ptr(viewseg,0));
     freemem(p,4000);
     cursor(true);
     writeln('ERROR: Parallel port LPT3 not found!');
     writeln('');
     halt(1);
   end;
  end;
  Mute;
  Function_Test;
  Mute;
 end
 else
 begin

 Window(20,3,60,6,15,1,true);
 fastwrite(22,3,14,1,' Port for Tandy sound chip (SN76489) ');
 fastwrite(33,4,15,1,'Port:');
 DrawSelector(38,4,'0C0h');

 Window(5,8,39,22,15,1,true);
 fastwrite(8,8,14,1,' Square wave tone generators ');

 fastwrite(7,10,15,1,'Tone generator 1: ');
 fastwrite(10,11,14,1,'Frequency:');
 DrawSelector(21,11,'OFF');
 fastwrite(10,12,14,1,'Volume:');
 DrawSelector(21,12,'100%');

 fastwrite(7,14,15,1,'Tone generator 2: ');
 fastwrite(10,15,14,1,'Frequency:');
 DrawSelector(21,15,'OFF');
 fastwrite(10,16,14,1,'Volume:');
 DrawSelector(21,16,'100%');

 fastwrite(7,18,15,1,'Tone generator 3: ');
 fastwrite(10,19,14,1,'Frequency:');
 DrawSelector(21,19,'OFF');
 fastwrite(10,20,14,1,'Volume:');
 DrawSelector(21,20,'100%');


 Window(43,8,76,14,15,1,true);
 fastwrite(52,8,14,1,' Noise generator ');
 fastwrite(45,10,14,1,'Frequency:');
 DrawSelector(57,10,'1748 Hz');
 fastwrite(45,11,14,1,'Volume:');
 DrawSelector(57,11,'OFF');
 fastwrite(45,12,14,1,'Noise:');
 DrawSelector(57,12,'Periodic');

 Window(43,16,76,22,15,1,true);
 Button(51,18,mbutton,false);
 Button(49,20,fbutton,false);




 if keyboardmode then Mark(40,4,4);



 ViewBuffer(p);


 if not keyboardmode then mouse_show;

 repeat;
    if not keyboardmode then
    begin
      Mouse_Read;
      xp := (mouse.x div 8)+1;
      yp := (mouse.y div 8)+1;
    end;

    if (mouse.b = 1) or (iskeypressed = true) then
    begin
      if iskeypressed then  key := getkey;
      while iskeypressed do getkey;
       Control_options;
    end;

 until key = #27;

 Mute;
 mouse_hide;
 clrscr;
 writeto(ptr(viewseg,0));
 end;

 freemem(p,4000);
 cursor(true);
 writeln(title);
 writeln('Greetings to Matze79 and PeDeWacht');
 writeln('');
end.

