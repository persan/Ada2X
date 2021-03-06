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

with Ada.Strings.Unbounded;

package Ada2X.Options is

   use Ada.Strings.Unbounded;

   Initialized : Boolean := False;
   --  Set to True by Initialize, if initialization is successful

   Verbose        : Boolean := False;
   --  If this flag is set ON, Ada2X generates the message about itself,
   --  including ASIS/GNAT version with which it is built.

   Quiet          : Boolean := False;
   --  If this flag is set ON, Ada2X does not output information about the
   --  generated SOAP routines.

   Overwrite_WSDL : Boolean := False;
   --  Should an existing WSDL be overwritten


   File_Name      : Unbounded_String;
   --  Input Ada spec filename

   WSDL_File_Name : Unbounded_String;
   --  Output WSDL document filename

   WS_Name        : Unbounded_String;
   --  Name of the Web Service, default value is the name of the Ada package

   Tree_File_Path : Unbounded_String;
   --  Path to the generated tree file, this is needed when, for example, using
   --  a project file whose object directory is not the current directory.

   Enum_To_String : Boolean := False;
   --  If True all enumeration types will be mapped to strings

   Debug          : Boolean := False;
   --  Do not generate date/time tag into the WSDL document for being able to
   --  compare them. This is an internal option only.

   procedure Set_Default;
   --  Set default path options for the Asis compile step

end Ada2X.Options;
