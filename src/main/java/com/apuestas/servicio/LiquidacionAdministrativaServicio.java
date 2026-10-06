package com.apuestas.servicio;

import com.apuestas.dao.LiquidacionAdministrativaDAO;
import com.apuestas.modelo.LiquidacionAdministrativaModelos.*;
import com.apuestas.modelo.OperacionLiquidacionAdministrativa;
import java.sql.SQLException;
import java.util.*;
import static com.apuestas.modelo.OperacionLiquidacionAdministrativa.*;

/** Barrera administrativa; los importes y las operaciones financieras pertenecen exclusivamente al SP. */
public class LiquidacionAdministrativaServicio {
    private final LiquidacionAdministrativaDAO dao;
    public LiquidacionAdministrativaServicio() { this(new LiquidacionAdministrativaDAO()); }
    public LiquidacionAdministrativaServicio(LiquidacionAdministrativaDAO dao) { this.dao=Objects.requireNonNull(dao); }
    public static void autorizar(OperacionLiquidacionAdministrativa op,int actor,String rol) {
        if(op==null) throw new IllegalArgumentException();
        if(actor<=0||!("ADMINISTRADOR".equals(rol)||"CAJERO".equals(rol)
                ||(op==CONSULTAR&&"AUDITOR".equals(rol)))) throw new SecurityException();
    }
    public static int parametro(OperacionLiquidacionAdministrativa op,Map<String,String[]> params) {
        if(op==null||params==null) throw new IllegalArgumentException();
        for(Map.Entry<String,String[]> e:params.entrySet())
            if(!op.parametro.equals(e.getKey())||e.getValue()==null||e.getValue().length!=1||e.getValue()[0]==null)
                throw new IllegalArgumentException();
        String[] valores=params.get(op.parametro);
        if(valores==null&&op==LISTAR) return 100;
        if(valores==null) throw new IllegalArgumentException();
        String v=valores[0].trim();
        if(!v.matches("[0-9]{1,10}")) throw new IllegalArgumentException();
        int n=Integer.parseInt(v);
        if(n<=0||(op==LISTAR&&n>500)) throw new IllegalArgumentException();
        return n;
    }
    public List<BoletoListo> listar(int actor,String rol,int cantidad) throws SQLException {
        autorizar(LISTAR,actor,rol);
        if(cantidad<1||cantidad>500) throw new IllegalArgumentException();
        return Objects.requireNonNull(dao.listar(actor,cantidad));
    }
    public Resultado liquidar(int actor,String rol,int idBoleto,String ip) throws SQLException {
        autorizar(LIQUIDAR,actor,rol);
        if(idBoleto<=0) throw new IllegalArgumentException();
        String origen=ip==null?null:ip.trim();
        if(origen!=null&&origen.isEmpty()) origen=null;
        if(origen!=null&&origen.length()>45) throw new IllegalArgumentException();
        return Objects.requireNonNull(dao.liquidar(actor,idBoleto,origen));
    }
    public Consulta consultar(int actor,String rol,int idBoleto) throws SQLException {
        autorizar(CONSULTAR,actor,rol);
        if(idBoleto<=0) throw new IllegalArgumentException();
        return Objects.requireNonNull(dao.consultar(actor,idBoleto));
    }
}