------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2003-2013, AdaCore                     --
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

with Ada.Calendar;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Exceptions;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.Calendar.Time_IO;

with Ada2X.Utils;
with Ada2X.Options;

package body Ada2X.Generator is

   use Ada;
   use Ada.Strings.Unbounded;

   --  Data structure for API's description

   type Parameter;
   type Parameter_Access is access Parameter;

   type Parameter is record
      Name      : Unbounded_String;
      Type_Name : Unbounded_String;
      XSD_Name  : Unbounded_String;
      Next      : Parameter_Access;
   end record;

   type Mode is (Routine, Safe_Pointer_Definition,
                 Structure, Table, Simple_Type, Enumeration);

   type Definition (Def_Mode : Mode := Routine) is record
      Name       : Unbounded_String;
      NS         : Unbounded_String;
      Parameters : Parameter_Access;
      Last       : Parameter_Access;

      case Def_Mode is
         when Routine =>
            Return_Type : Parameter_Access;

         when Table =>
            Length : Natural;

         when Structure | Simple_Type | Enumeration =>
            null;

         when Safe_Pointer_Definition =>
            Type_Name, Access_Name : Unbounded_String;
      end case;
   end record;

   type Profiles is array (Positive range <>) of Definition;

   Max_Definition : constant := 1_024;

   API   : Profiles (1 .. Max_Definition);
   Index : Natural := 0;

   Schema_Needed : Boolean := False;
   --  Set to True if a WSDL schema is to be writed

   Character_Schema : constant Boolean := False;
   --  Set to Trus if a WSDL Character schema must be generated

   package NS_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (String, Positive, Ada.Strings.Hash, "=", "=");

   Name_Spaces : NS_Maps.Map;
   NS_Num      : Natural := 0;

   procedure Insert_NS (Value : String);
   --  Insert a new namespace value into Name_Spaces table

   function NS_Prefix (Value : String) return String;
   pragma Unreferenced (NS_Prefix);
   --  Returns the name space prefix for the given name space value

   function "+" (S : String) return Unbounded_String
      renames To_Unbounded_String;

   function "-" (S : Unbounded_String) return String
      renames To_String;

   function To_XSD (NS, Ada_Type : String) return String;

   procedure Check_Routine (Name : String);
   --  Checks the routine name, no overloading is allowed, raises
   --  Constraint_Error if name already exits.

   -------------------
   -- Check_Routine --
   -------------------

   procedure Check_Routine (Name : String) is
      use Exceptions;
   begin
      for I in 1 .. Index loop
         if API (I).Def_Mode = Routine
           and then To_String (API (I).Name) = Name
         then
            Raise_Exception
              (Spec_Error'Identity,
               "routine " & Name & " already found, no overloading allowed.");
         end if;
      end loop;
   end Check_Routine;

   ---------------
   -- Insert_NS --
   ---------------

   procedure Insert_NS (Value : String) is
      P       : NS_Maps.Cursor;
      Success : Boolean;
   begin
      if not Name_Spaces.Contains (Value) then
         NS_Num := NS_Num + 1;
         Name_Spaces.Insert (Value, NS_Num, P, Success);
      end if;
   end Insert_NS;

   -------------------
   -- New_Component --
   -------------------

   procedure New_Component (NS, Comp_Name, Comp_Type : String) is

      New_P : constant Parameter_Access :=
                new Parameter'
                  (+Comp_Name, +Comp_Type, +To_XSD (NS, Comp_Type), null);
   begin
      if Options.Verbose then
         Text_IO.Put_Line
           ("        " & Comp_Name & " : " & Comp_Type
              & " (" & (-New_P.XSD_Name) & ')');
      end if;

      if API (Index).Parameters = null then
         API (Index).Parameters := New_P;
      else
         API (Index).Last.Next := New_P;
      end if;

      API (Index).Last := New_P;
   end New_Component;

   ----------------
   -- New_Formal --
   ----------------

   procedure New_Formal (NS, Var_Name, Var_Type : String) is
      New_P : constant Parameter_Access :=
                new Parameter'
                  (+Var_Name, +Var_Type, +To_XSD (NS, Var_Type), null);
   begin
      if Options.Verbose then
         Text_IO.Put_Line
           ("        " & Var_Name & " : " & Var_Type
              & " (" & (-New_P.XSD_Name) & ')');
      end if;

      if API (Index).Parameters = null then
         API (Index).Parameters := New_P;
      else
         API (Index).Last.Next := New_P;
      end if;

      API (Index).Last := New_P;
   end New_Formal;

   -----------------
   -- New_Literal --
   -----------------

   procedure New_Literal (Name : String) is
      New_P : constant Parameter_Access :=
                new Parameter'(+Name, +"", +"", null);
   begin
      if Options.Verbose then
         Text_IO.Put_Line ("        " & Name);
      end if;

      if API (Index).Parameters = null then
         API (Index).Parameters := New_P;
      else
         API (Index).Last.Next := New_P;
      end if;

      API (Index).Last := New_P;
   end New_Literal;

   ---------------
   -- NS_Prefix --
   ---------------

   function NS_Prefix (Value : String) return String is
   begin
      if Value = "" then
         return "tns";
      else
         return 'n' & Utils.Image (Name_Spaces.Element (Value));
      end if;
   end NS_Prefix;

   ----------------------
   -- Register_Derived --
   ----------------------

   procedure Register_Derived (NS, Name, Parent_Name : String) is
      New_P : constant Parameter_Access :=
                new Parameter'
                  (+Name, +Parent_Name, +To_XSD (NS, Parent_Name), null);
      D     : Definition (Simple_Type);
   begin
      --  We need to write a schema for this derived type
      Schema_Needed := True;

      D.NS         := +NS;
      D.Name       := +Name;
      D.Parameters := New_P;

      Index := Index + 1;
      API (Index) := D;

      if not Options.Quiet then
         Text_IO.Put
           ("   - derived         " & Name & " is new " & Parent_Name);

         if Options.Verbose then
            Text_IO.Put_Line (" (" & (-New_P.XSD_Name) & ')');
         else
            Text_IO.New_Line;
         end if;
      end if;
   end Register_Derived;

   ---------------------------
   -- Register_Safe_Pointer --
   ---------------------------

   procedure Register_Safe_Pointer
     (Name, Type_Name, Access_Name : String)
   is
      use Exceptions;
      D : Definition (Safe_Pointer_Definition);
   begin
      if Name /= Type_Name & "_Safe_Pointer" then
         Raise_Exception
           (Spec_Error'Identity,
            "Package Safe_Pointers instantiation must be named "
            & Type_Name & "_Safe_Pointer.");
      end if;

      D.Name        := +Name;
      D.Type_Name   := +Type_Name;
      D.Access_Name := +Access_Name;

      Index := Index + 1;
      API (Index) := D;

      if not Options.Quiet then
         Text_IO.Put_Line
           ("   - safe pointer  " & Name
              & " (" & Type_Name & ", " & Access_Name & ")");
      end if;
   end Register_Safe_Pointer;

   -------------------
   -- Register_Type --
   -------------------

   procedure Register_Type (NS, Name, Root_Name : String) is
      New_P : constant Parameter_Access :=
                new Parameter'
                  (+Name, +Root_Name, +To_XSD (NS, Root_Name), null);
      D     : Definition (Simple_Type);
   begin
      --  We need to write a schema for this derived type
      Schema_Needed := True;

      D.NS         := +NS;
      D.Name       := +Name;
      D.Parameters := New_P;

      Index := Index + 1;
      API (Index) := D;

      if not Options.Quiet then
         Text_IO.Put
           ("   - new type        " & Name & " is " & Root_Name);

         if Options.Verbose then
            Text_IO.Put_Line (" (" & (-New_P.XSD_Name) & ')');
         else
            Text_IO.New_Line;
         end if;
      end if;
   end Register_Type;

   -----------------
   -- Return_Type --
   -----------------

   procedure Return_Type (NS, Name : String) is
      New_P : constant Parameter_Access :=
                new Parameter'(+"Result", +Name, +To_XSD (NS, Name), null);
   begin
      if Options.Verbose then
         Text_IO.Put_Line
           ("        return " & Name & " (" & (-New_P.XSD_Name) & ')');
      end if;

      API (Index).Return_Type := New_P;
   end Return_Type;

   -----------------
   -- Start_Array --
   -----------------

   procedure Start_Array
     (NS, Name, Component_Type : String;
      Length                   : Natural := 0)
   is
      New_P : constant Parameter_Access :=
                new Parameter'(+"item", +Component_Type,
                               +To_XSD (NS, Component_Type), null);
      D     : Definition (Table);
   begin
      --  We need to write a schema for this record
      Schema_Needed := True;

      D.NS         := +NS;
      D.Name       := +Name;
      D.NS         := +NS;
      D.Parameters := New_P;
      D.Length     := Length;

      Index := Index + 1;
      API (Index) := D;

      if not Options.Quiet then
         Text_IO.Put ("   - array (");
         if Length = 0 then
            --  An unconstrained array
            Text_IO.Put ("<>");
         else
            Text_IO.Put (Utils.Image (Length));
         end if;
         Text_IO.Put (")");
         Text_IO.Set_Col (22);
         Text_IO.Put (Name & " of " & Component_Type);

         if Options.Verbose then
            Text_IO.Put_Line (" (" & (-New_P.XSD_Name) & ')');
         else
            Text_IO.New_Line;
         end if;
      end if;
   end Start_Array;

   -----------------------
   -- Start_Enumeration --
   -----------------------

   procedure Start_Enumeration (NS, Name : String) is
      D : Definition (Enumeration);
   begin
      --  We need to write a schema for this derived type
      Schema_Needed := True;

      Insert_NS (NS);

      D.NS         := +NS;
      D.Name       := +Name;
      D.Parameters := null;

      Index := Index + 1;
      API (Index) := D;

      if not Options.Quiet then
         Text_IO.Put_Line ("   - enumeration     " & Name);
      end if;
   end Start_Enumeration;

   ------------------
   -- Start_Record --
   ------------------

   procedure Start_Record (NS, Name : String) is
      D : Definition (Structure);
   begin
      --  We need to write a schema for this record
      Schema_Needed := True;

      Insert_NS (NS);

      D.NS   := +NS;
      D.Name := +Name;

      Index := Index + 1;
      API (Index) := D;

      if not Options.Quiet then
         Text_IO.Put_Line ("   - record          " & Name);
      end if;
   end Start_Record;

   -------------------
   -- Start_Routine --
   -------------------

   procedure Start_Routine (Name, Comment : String) is
      D : Definition (Routine);
   begin
      Check_Routine (Name);

      D.Name := +Name;

      Index := Index + 1;
      API (Index) := D;

      if not Options.Quiet then
         Text_IO.Put_Line ("   > " & Comment & "       " & Name);
      end if;
   end Start_Routine;

   ------------
   -- To_XSD --
   ------------

   function To_XSD (NS, Ada_Type : String) return String is
   begin
      Insert_NS (NS);
      return Ada_Type;
   end To_XSD;

   -----------------
   -- Type_Exists --
   -----------------

   function Type_Exists (NS, Name : String) return Boolean is
   begin
      for I in 1 .. Index loop
         if API (I).Def_Mode = Structure
           or else API (I).Def_Mode = Simple_Type
           or else API (I).Def_Mode = Enumeration
           or else API (I).Def_Mode = Table
         then
            if -API (I).Name = Name and then -API (I).NS = NS then
               return True;
            end if;
         end if;
      end loop;

      return False;
   end Type_Exists;

   -----------
   -- Write --
   -----------

   procedure Write (Filename : String) is

      use Ada.Text_IO;

      WS_Name : constant String := -Options.WS_Name;

      NS      : constant String := WS_Name & "_def/";

      procedure Write_Header;
      --  Write WSDL header

      procedure Write_Schema;
      --  Write WSDL schema, types tag

      procedure Write_Messages;
      --  Write WSDL message tags

      procedure Write_Port_Type;
      --  Write WSDL portType tag

      procedure Write_Binding;
      --  Write WSDL binding tag

      procedure Write_Service;
      --  Write WSDL service tag

      procedure Write_Footer;
      --  Write WSDL footer, close definition tag

      -------------------
      -- Write_Binding --
      -------------------

      procedure Write_Binding is

         procedure Write_Operation (R : Definition);

         ---------------------
         -- Write_Operation --
         ---------------------

         procedure Write_Operation (R : Definition) is

            procedure Write_SOAP_Body;

            ---------------------
            -- Write_SOAP_Body --
            ---------------------

            procedure Write_SOAP_Body is
            begin
               Put_Line ("            <soap:body");
               Put_Line ("               encodingStyle="""
                           & "http://schemas.xmlsoap.org/soap/encoding/""");
               Put_Line ("               namespace=""" & NS & '"');
               Put_Line ("               use=""encoded""/>");
            end Write_SOAP_Body;

            Name : constant String := -R.Name;

         begin
            Put_Line ("      <wsdl:operation name=""" & Name & """>");
            Put_Line ("         <soap:operation soapAction="""
                        & Name & """/>");
            Put_Line ("         <wsdl:input>");
            Write_SOAP_Body;
            Put_Line ("         </wsdl:input>");
            Put_Line ("         <wsdl:output>");
            Write_SOAP_Body;
            Put_Line ("         </wsdl:output>");
            Put_Line ("      </wsdl:operation>");
         end Write_Operation;

      begin
         New_Line;
         Put_Line ("   <wsdl:binding name="""
                   & WS_Name & "_Binding"" type=""tns:"
                   & WS_Name & "_PortType"">");
         Put_Line ("      <soap:binding style=""rpc""");
         Put_Line ("         transport="""
                     & "http://schemas.xmlsoap.org/soap/http""/>");

         --  Output all operations info

         for I in 1 .. Index loop
            if API (I).Def_Mode = Routine then
               New_Line;
               Write_Operation (API (I));
            end if;
         end loop;

         Put_Line ("   </wsdl:binding>");
      end Write_Binding;

      ------------------
      -- Write_Footer --
      ------------------

      procedure Write_Footer is
      begin
         Put_Line ("</wsdl:definitions>");
      end Write_Footer;

      ------------------
      -- Write_Header --
      ------------------

      procedure Write_Header is
         P : NS_Maps.Cursor;
         N : Positive;
      begin
         Put_Line ("<?xml version=""1.0"" encoding=""UTF-8""?>");
         Put_Line ("<wsdl:definitions name=""" & WS_Name  & """");
         Put_Line ("   targetNamespace=""" & NS & '"');
         Put_Line ("   xmlns:tns=""" & NS & '"');

         --  Write all name spaces

         P := Name_Spaces.First;

         while NS_Maps.Has_Element (P) loop
            N := NS_Maps.Element (P);

            New_Line;
            Put ("   xmlns:n" & Utils.Image (N)
                 & "=""" & NS_Maps.Key (P) & '"');
            P := NS_Maps.Next (P);
         end loop;

         --  Close definition

         Put_Line (">");

         --  Write AWS/Ada2X tag

         if not Options.Debug then
            New_Line;
            Put_Line ("   <!-- Generated by AWS/Ada2X v" & Version);
            Put_Line ("        on " & GNAT.Calendar.Time_IO.Image
                      (Ada.Calendar.Clock, "%A %d %B %Y at %T") & " -->");
         end if;
      end Write_Header;

      --------------------
      -- Write_Messages --
      --------------------

      procedure Write_Messages is

         procedure Write_Message (R : Definition);

         ---------------------
         -- Write_Operation --
         ---------------------

         procedure Write_Message (R : Definition) is

            procedure Write_Part (P : Parameter_Access);

            ----------------
            -- Write_Part --
            ----------------

            procedure Write_Part (P : Parameter_Access) is
               A : Parameter_Access := P;
            begin
               while A /= null loop
                  Put_Line
                    ("      <wsdl:part name=""" & (-A.Name)
                     & """ type=""" & (-A.XSD_Name) & """/>");
                  A := A.Next;
               end loop;
            end Write_Part;

            Name : constant String := -R.Name;

         begin
            New_Line;

            if R.Parameters /= null then
               Put_Line ("   <wsdl:message name=""" & Name & "_Request"">");
               Write_Part (R.Parameters);
               Put_Line ("   </wsdl:message>");
            end if;

            New_Line;

            if R.Return_Type /= null then
               Put_Line ("   <wsdl:message name=""" & Name & "_Response"">");
               Write_Part (R.Return_Type);
               Put_Line ("   </wsdl:message>");
            end if;
         end Write_Message;

      begin
         for I in 1 .. Index loop
            if API (I).Def_Mode = Routine then
               Write_Message (API (I));
            end if;
         end loop;
      end Write_Messages;

      ---------------------
      -- Write_Port_Type --
      ---------------------

      procedure Write_Port_Type is

         procedure Write_Operation (R : Definition);

         ---------------------
         -- Write_Operation --
         ---------------------

         procedure Write_Operation (R : Definition) is

            Name : constant String := -R.Name;

         begin
            Put_Line ("      <wsdl:operation name=""" & Name & """>");

            if R.Parameters /= null then
               --  Notification operation
               Put_Line
                 ("         <wsdl:input message=""tns:"
                  & Name & "_Request""/>");
            end if;

            if R.Return_Type /= null then
               --  Request-response operation
               Put_Line
                 ("         <wsdl:output message=""tns:"
                  & Name & "_Response""/>");
            end if;

            Put_Line ("      </wsdl:operation>");
         end Write_Operation;

         Found : Boolean := False;

      begin
         New_Line;
         Put_Line ("   <wsdl:portType name=""" & WS_Name & "_PortType"">");

         --  Output all operations info

         for I in 1 .. Index loop
            if API (I).Def_Mode = Routine then
               if Found then
                  New_Line;
               else
                  Found := True;
               end if;
               Write_Operation (API (I));
            end if;
         end loop;

         Put_Line ("   </wsdl:portType>");
      end Write_Port_Type;

      ------------------
      -- Write_Schema --
      ------------------

      procedure Write_Schema is

         procedure Write_Array (E : Definition);
         --  Write array element tags

         procedure Write_Record (E : Definition);
         --  Write record element tags

         procedure Write_Type (E : Definition);
         --  Write a derived type (simpleType)

         procedure Write_Enumeration (E : Definition);
         --  Write an enumeration type definition (simpleType)

         procedure Write_Character;
         --  Write the Character schema

         -----------------
         -- Write_Array --
         -----------------

         procedure Write_Array (E : Definition) is
         begin
            New_Line;
            Put_Line ("         <xsd:complexType name=""" & (-E.Name) & '"');
            Put_Line ("                 targetNamespace=""" & (-E.NS) & """>");
            Put_Line ("            <xsd:complexContent>");
            Put_Line ("               <xsd:restriction "
                      & "base=""soapenc:Array"">");
            Put_Line ("                  <xsd:attribute "
                      & "ref=""soapenc:arrayType"""
                      & " wsdl:arrayType=""" & (-E.Parameters.XSD_Name)
                      & (if E.Length = 0
                         then "[]"
                         else "[" & Utils.Image (E.Length) & "]")
                      & """/>");
            Put_Line ("               </xsd:restriction>");
            Put_Line ("            </xsd:complexContent>");
            Put_Line ("         </xsd:complexType>");
         end Write_Array;

         ---------------------
         -- Write_Character --
         ---------------------

         procedure Write_Character is
         begin
            New_Line;
            Put_Line ("         <xsd:simpleType name=""Character""");
            Put_Line ("                 targetNamespace=""Standard_pkg/" & """>");
            Put_Line ("            <xsd:restriction base=""xsd:string"">");
            Put_Line ("               <xsd:length value=""1""/>");
            Put_Line ("            </xsd:restriction>");
            Put_Line ("         </xsd:simpleType>");
         end Write_Character;

         -----------------------
         -- Write_Enumeration --
         -----------------------

         procedure Write_Enumeration (E : Definition) is
            P : Parameter_Access := E.Parameters;
         begin
            New_Line;
            Put_Line ("         <xsd:simpleType name=""" & (-E.Name) & '"');
            Put_Line ("                 targetNamespace=""" & (-E.NS) & """>");
            Put_Line ("            <xsd:restriction base=""xsd:string"">");

            while P /= null loop
               Put_Line ("               <xsd:enumeration value="""
                           & (-P.Name) & """/>");
               P := P.Next;
            end loop;

            Put_Line ("            </xsd:restriction>");
            Put_Line ("         </xsd:simpleType>");
         end Write_Enumeration;

         ------------------
         -- Write_Record --
         ------------------

         procedure Write_Record (E : Definition) is
            P : Parameter_Access := E.Parameters;
         begin
            New_Line;
            Put_Line ("         <xsd:complexType name=""" & (-E.Name) & '"');
            Put_Line ("                 targetNamespace=""" & (-E.NS) & """>");
            Put_Line ("            <xsd:all>");

            while P /= null loop
               Put_Line ("               <xsd:element name=""" & (-P.Name)
                           & """ type=""" & (-P.XSD_Name) & """/>");
               P := P.Next;
            end loop;

            Put_Line ("            </xsd:all>");
            Put_Line ("         </xsd:complexType>");
         end Write_Record;

         ----------------
         -- Write_Type --
         ----------------

         procedure Write_Type (E : Definition) is
            P : constant Parameter_Access := E.Parameters;
         begin
            New_Line;
            Put_Line ("         <xsd:simpleType name=""" & (-E.Name) & '"');
            Put_Line ("                 targetNamespace=""" & (-E.NS) & """>");
            Put_Line ("            <xsd:restriction base="""
                        & (-P.XSD_Name) & """/>");
            Put_Line ("         </xsd:simpleType>");
         end Write_Type;

      begin
         if Schema_Needed or else Character_Schema then
            New_Line;
            Put_Line ("   <wsdl:types>");
            Put
              ("      <xsd:schema"
               & " xmlns:xsd=""http://www.w3.org/2001/XMLSchema""");

            --  The following code is to check if all schema definitions are
            --  having the same namespace. If so, we place a targetNamespace
            --  node into the main schema node. This is to work around a
            --  Microsoft .Net toolset bug where targetNamespace into schema's
            --  type definitions are not taken into account. This is of course
            --  mandatory to avoid name clashes (in Ada two types with the same
            --  name in different packages for example).

            declare
               Global_NS : Unbounded_String;
               Single_NS : Boolean := True;
            begin
               for I in 1 .. Index loop
                  case API (I).Def_Mode is
                     when Structure | Table | Simple_Type | Enumeration =>
                        if Global_NS = Null_Unbounded_String then
                           Global_NS := API (I).NS;

                        elsif Global_NS /= API (I).NS then
                           Single_NS := False;
                        end if;

                     when Safe_Pointer_Definition | Routine =>
                        null;
                  end case;
               end loop;

               if Single_NS then
                  New_Line;
                  Put ("         targetNamespace=""" & (-Global_NS) & '"');
               end if;

               --  Finally, close schema
               Put_Line (">");
            end;

            if Character_Schema then
               Write_Character;
            end if;

            --  Output all structures

            for I in 1 .. Index loop
               case API (I).Def_Mode is
                  when Structure   => Write_Record (API (I));
                  when Table       => Write_Array (API (I));
                  when Simple_Type => Write_Type (API (I));
                  when Enumeration => Write_Enumeration (API (I));

                  when Safe_Pointer_Definition | Routine =>
                     null;
               end case;
            end loop;

            Put_Line ("      </xsd:schema>");
            Put_Line ("   </wsdl:types>");
         end if;
      end Write_Schema;

      -------------------
      -- Write_Service --
      -------------------

      procedure Write_Service is
      begin
         New_Line;
      end Write_Service;

      File : Text_IO.File_Type;

   begin
      Create (File, Out_File, Filename);

      Text_IO.Set_Output (File);

      Write_Header;

      Write_Schema;

      Write_Messages;

      Write_Port_Type;

      Write_Binding;

      Write_Service;

      Write_Footer;

      Set_Output (Current_Output);
   end Write;

end Ada2X.Generator;
