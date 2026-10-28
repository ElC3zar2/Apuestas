package com.apuestas.controlador;

import com.apuestas.dao.*;
import com.apuestas.modelo.*;
import com.apuestas.modelo.ConsultasAdministrativasModelos.*;
import com.apuestas.servicio.ConsultasAdministrativasServicio;
import java.sql.*;
import java.util.*;
import static com.apuestas.controlador.PruebaLoginAdministrativo.exigir;

/** HTTP, servicio, DAO real y JDBC controlado. No abre conexiones ni prueba el motor SQL. */
public class PruebaBusquedaUsuariosAdministrativa {
    private static int casos;
    private static void comprobar(boolean valor){exigir(valor);casos++;}
    private static final class Fuente extends PruebaCierreAdministrativo.Jdbc {
        Fuente(String estado){rows.add(PruebaCierreAdministrativo.fila("IdUsuario",9,"Nombre","Ana","Apellido","Lopez",
                "Correo","ana@example.test","EstadoUsuario",estado,"Rol","USUARIO"));}
        AdministracionUsuarioDAO dao(){return new AdministracionUsuarioDAO(){
            @Override protected Connection obtenerConexion(){return conexion();}
        };}
    }
    private static PruebaCierreAdministrativo.Api api(Fuente fuente,String rol){
        PruebaCierreAdministrativo.Api api=new PruebaCierreAdministrativo.Api(OperacionConsultaAdministrativa.USUARIOS,rol);
        api.servicio=new ConsultasAdministrativasServicio(new EventoDAO(),fuente.dao(),new UbicacionDAO());
        return api;
    }
    public static void main(String[] args)throws Exception {
        for(String estado:new String[]{null,"PENDIENTE","ACTIVO","SUSPENDIDO","CERRADO"}){
            for(String texto:new String[]{"Ana","Lopez","Ana Lopez","ana@example.test","@example","","sin coincidencias","%_[]! O'Neil"}){
                Fuente f=new Fuente(estado==null?"ACTIVO":estado);
                if(texto.equals("sin coincidencias")){f.rows.clear();f.total=0;}
                PruebaCierreAdministrativo.Api a=api(f,"ADMINISTRADOR");a.p("buscar",texto);if(estado!=null)a.p("estado",estado);
                com.fasterxml.jackson.databind.JsonNode j=a.ejecutar(200);
                comprobar(j.path("total").asLong()==f.total&&j.path("usuarios").size()==f.rows.size());
                String count=f.sql.get(0),select=f.sql.get(1);
                comprobar(count.substring(count.indexOf(" FROM ")).equals(select.substring(select.indexOf(" FROM "),select.indexOf(" ORDER BY "))));
                comprobar(count.contains("R.Nombre='USUARIO'")&&count.contains("TE.Codigo='USUARIO'")&&select.endsWith("ORDER BY U.Correo,U.IdUsuario OFFSET ? ROWS FETCH NEXT ? ROWS ONLY"));
                comprobar(count.contains("E.Codigo=?")== (estado!=null));
                Map<Integer,Object> bindings=f.bindings.get(0);
                if(estado!=null)comprobar(bindings.get(1).equals(estado));
                if(!texto.isEmpty()){
                    String esperado="%"+texto.replace("!","!!").replace("%","!%").replace("_","!_").replace("[","![").replace("]","!]")+"%";
                    comprobar(bindings.get(estado==null?1:2).equals(esperado));
                    comprobar(!count.contains(texto));
                }
                comprobar(f.closeC==1&&f.closeP==2&&f.closeR==2);
            }
        }
        for(String rol:new String[]{"ADMINISTRADOR","AUDITOR","OPERADOR_EVENTOS","CAJERO"}){
            Fuente f=new Fuente("ACTIVO");api(f,rol).ejecutar(Arrays.asList("ADMINISTRADOR","AUDITOR").contains(rol)?200:403);
            comprobar(f.sql.size()==(Arrays.asList("ADMINISTRADOR","AUDITOR").contains(rol)?2:0));
        }
        for(String[] valor:new String[][]{{"TODOS"},{""},{"NO_EXISTE"},{"ACTIVO","PENDIENTE"}}){
            Fuente f=new Fuente("ACTIVO");PruebaCierreAdministrativo.Api a=api(f,"ADMINISTRADOR");a.p("estado",valor);a.ejecutar(400);comprobar(f.sql.isEmpty());
        }
        for(String key:new String[]{"buscar","pagina","tamanoPagina","otro"}){
            Fuente f=new Fuente("ACTIVO");PruebaCierreAdministrativo.Api a=api(f,"ADMINISTRADOR");a.p(key,"1","2");a.ejecutar(400);comprobar(f.sql.isEmpty());
        }
        for(String value:new String[]{"0","-1","2147483648","9999999999","1.5"}){
            Fuente f=new Fuente("ACTIVO");PruebaCierreAdministrativo.Api a=api(f,"ADMINISTRADOR");a.p("pagina",value);a.ejecutar(400);comprobar(f.sql.isEmpty());
        }
        Fuente f=new Fuente("SUSPENDIDO");PruebaCierreAdministrativo.Api a=api(f,"AUDITOR");a.p("estado","SUSPENDIDO");a.p("pagina","3");a.p("tamanoPagina","25");a.ejecutar(200);
        comprobar(f.bindings.get(1).get(2).equals(50L)&&f.bindings.get(1).get(3).equals(25));
        f=new Fuente("ACTIVO");f.rows.get(0).put("Nombre",null);f.rows.get(0).put("Apellido",null);api(f,"ADMINISTRADOR").ejecutar(200);comprobar(f.closeR==2);
        for(String rol:new String[]{"ADMINISTRADOR","CASA"}){
            f=new Fuente("ACTIVO");f.rows.get(0).put("Rol",rol);api(f,"ADMINISTRADOR").ejecutar(500);comprobar(f.closeR==2);
        }
        f=new Fuente("ACTIVO");f.fail=true;api(f,"ADMINISTRADOR").ejecutar(500);comprobar(f.closeC==1&&f.closeP==1);
        f=new Fuente("ACTIVO");a=api(f,"ADMINISTRADOR");a.h.previa=null;a.ejecutar(401);comprobar(f.sql.isEmpty());
        f=new Fuente("ACTIVO");a=api(f,"ADMINISTRADOR");a.h.previa.expirada=true;a.ejecutar(401);comprobar(f.sql.isEmpty());
        System.out.println("MEJORA-01 busqueda: "+casos+" comprobaciones, 0 fallos; JDBC simulado, sin SQL real.");
    }
}
