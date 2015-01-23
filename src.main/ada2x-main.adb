------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2003-2012, AdaCore                     --
--                                                                          --
--  This is free software;  you can redistribute it  and/or modify it       --
--  under terms of the  GNU General Public License as published  by the     --
--  Free Software  Foundation;  either version 3,  or (at your option) any  --
--  later version.  This software is distributed in the hope  that it will  --
--  be useful, but WITHOUT ANY WARRANTY;  without even the implied warranty --
--  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU     --
--  General Public License for  more details.                               --
--                                                                          --
--  You should have  received  a copy of the GNU General  Public  License   --
--  distributed  with  this  software;   see  file COPYING3.  If not, go    --
--  to http://www.gnu.org/licenses for a complete copy of the license.      --
------------------------------------------------------------------------------

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.Command_Line;


with Ada2X.Generator;
with Ada2X.Options;
with Ada2X.Parser;
with Ada.Directories;

procedure Ada2X.Main is

   use Ada;
   use Ada.Exceptions;
   use Ada.Strings.Unbounded;
   use Ada.Directories;
   procedure Usage;
   --  Display usage string

   procedure Parse_Command_Line;
   --  Parse command line and set options

   ------------------------
   -- Parse_Command_Line --
   ------------------------

   procedure Parse_Command_Line is
   begin
      loop
         case GNAT.Command_Line.Getopt ("f q v a: o: s: t: I: P: noenum d") is

            when ASCII.NUL =>
               exit;

            when 'f' =>
               Options.Overwrite_WSDL := True;

            when 'o' =>
               Options.WSDL_File_Name :=
                 To_Unbounded_String (GNAT.Command_Line.Parameter);

            when 't' =>
               Options.Tree_File_Path :=
                 To_Unbounded_String
                   (Ada.Directories.Full_Name(
                        (GNAT.Command_Line.Parameter)));


            when 's' =>
               Options.WS_Name :=
                 To_Unbounded_String (GNAT.Command_Line.Parameter);

            when 'q' =>
               Options.Quiet := True;

            when 'n' =>
               if GNAT.Command_Line.Full_Switch = "noenum" then
                  Options.Enum_To_String := True;
               else
                  Usage;
                  raise Parameter_Error;
               end if;

            when 'v' =>
               Options.Verbose := True;
               Text_IO.New_Line;
               Text_IO.Put_Line ("Ada2X v" & Version);

            when 'I' =>
               Parser.Add_Option ("-I" & GNAT.Command_Line.Parameter);

            when 'P' =>
               Parser.Add_Option ("-P" & GNAT.Command_Line.Parameter);

            when 'd' =>
               Options.Debug := True;

            when others =>
               Usage;
               raise Parameter_Error;
         end case;
      end loop;

      Options.File_Name :=
        To_Unbounded_String (GNAT.Command_Line.Get_Argument);

      if Options.WSDL_File_Name = Null_Unbounded_String then
         Options.WSDL_File_Name := Options.File_Name;
         Append (Options.WSDL_File_Name, ".wsdl");
      end if;

      --  If there is no argument file name or no destination directory,
      --  we will get empty strings here

      if To_String (Options.File_Name) = Null_Unbounded_String then
         Text_IO.Put_Line
           (Text_IO.Standard_Error, "Ada2X: file name missing");
         Usage;
         raise Parameter_Error;
      end if;

      if GNAT.Command_Line.Get_Argument /= "" then
         Text_IO.Put_Line
           (Text_IO.Standard_Error, "Ada2X: only one file name allowed");
         Usage;
         raise Parameter_Error;
      end if;

   exception
      when GNAT.Command_Line.Invalid_Switch =>
         Text_IO.Put_Line
           (Text_IO.Standard_Error,
            "Ada2X: invalid switch : " & GNAT.Command_Line.Full_Switch);
         Usage;

         raise Parameter_Error;

      when GNAT.Command_Line.Invalid_Parameter =>
         Text_IO.Put_Line
           (Text_IO.Standard_Error,
            "Ada2X: parameter missed for : "
              & GNAT.Command_Line.Full_Switch);
         Usage;

         raise Parameter_Error;
   end Parse_Command_Line;

   -----------
   -- Usage --
   -----------

   procedure Usage is
      use Text_IO;

      Current_Output : constant File_Access := Text_IO.Current_Output;
   begin
      Set_Output (Standard_Error);

      New_Line;
      Put_Line ("Usage: ada2wsdl [opts] filename");
      New_Line;
      Put_Line ("ada2wsdl options:");
      New_Line;
      Put_Line ("  -f       Replace an existing WSDL document");
      Put_Line ("  -q       Quiet mode");
      Put_Line ("  -v       Verbose mode - output the version");
      Put_Line
        ("  -I path  A path to a directory containing a set of sources");
      Put_Line
        ("  -P proj  A project file to use for building the spec");
      Put_Line ("  -o file  WSDL file, <filename>.wsdl by default");
      Put_Line ("  -t path  Path to tree file directory");
      Put_Line ("  -a url   Web Service server address (URL)");
      Put_Line ("  -s name  Web Service name (default package name)");
      Put_Line ("  -noenum  Map Ada enumeration to xsd:string");

      Set_Output (Current_Output.all);
   end Usage;

begin
   Options.Set_Default;

   Parse_Command_Line;

   Parser.Initialize;

   if not Options.Initialized then
      return;
   end if;

   declare
      Filename : constant String := To_String (Options.WSDL_File_Name);
   begin
      if Kind (Filename) = Ordinary_File
        and then not Options.Overwrite_WSDL
      then
         Text_IO.Put_Line
           (Text_IO.Standard_Error,
            Filename & " already exists, use -f option to replace.");
         Usage;
         raise Parameter_Error;
      end if;

      Parser.Start;

      Generator.Write (Filename);
   end;

   Parser.Clean_Up;

exception

   when Fatal_Error | Parameter_Error =>
      --  Everything has already been reported
      Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);

   when E : Spec_Error =>
      Text_IO.New_Line;
      Text_IO.Put_Line ("ada2wsdl: " & Exception_Message (E));
      Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);

   when E : others =>
      Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);

      declare
         Current_Output : constant Text_IO.File_Access
           := Text_IO.Current_Output;
      begin
         Text_IO.Set_Output (Text_IO.Standard_Error);
         Text_IO.New_Line;

         if Exception_Identity (E) = Program_Error'Identity
           and then
             Exception_Message (E) = "Inconsistent versions of GNAT and ASIS"
         then
            Text_IO.Put_Line ("Ada2X v" & Version);
            Text_IO.New_Line;
            Text_IO.Put ("is inconsistent with the GNAT version");
            Text_IO.New_Line;
            Text_IO.Put_Line
              ("Check your installation of GNAT, ASIS and the GNAT toolset");

         else
            Text_IO.Put_Line ("Unexpected bug in Ada2X v" & Version);
            Text_IO.New_Line;
            Text_IO.Put (Exception_Name (E));
            Text_IO.Put (" was raised: ");

            if Exception_Message (E)'Length = 0 then
               Text_IO.Put_Line ("(no exception message)");
            else
               Text_IO.Put_Line (Exception_Message (E));
            end if;

            Text_IO.Put_Line ("Please report.");
            Text_IO.Set_Output (Current_Output.all);
         end if;
      end;

      Parser.Clean_Up;
end Ada2X.Main;
