/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.Participante;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
/**
 *
 * @author farfa
 */
public class ParticipanteDAO {

    public Participante crearParticipante(int idUsuarioProceso,
                                          Participante participante,
                                          String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_CrearParticipante(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, participante.getIdDeporte());
            cs.setString(3, participante.getNombre());
            cs.setString(4, participante.getTipoParticipante());

            if (participante.getIdPais() != null) {
                cs.setInt(5, participante.getIdPais());
            } else {
                cs.setNull(5, Types.INTEGER);
            }

            establecerIp(cs, 6, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearParticipante(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_CrearParticipante no devolvió el participante creado.");
    }

    public Participante actualizarParticipante(
            int idUsuarioProceso,
            Participante participante,
            String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_ActualizarParticipante(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, participante.getIdParticipante());
            cs.setString(3, participante.getNombre());

            if (participante.getIdPais() != null) {
                cs.setInt(4, participante.getIdPais());
            } else {
                cs.setNull(4, Types.INTEGER);
            }

            cs.setBoolean(5, participante.isActivo());

            establecerIp(cs, 6, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearParticipante(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_ActualizarParticipante no devolvió el participante actualizado.");
    }

    public List<Participante> listarParticipantes()
            throws SQLException {

        List<Participante> participantes =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "IdParticipante, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "TipoParticipante, "
                + "Activo "
                + "FROM dbo.Participante "
                + "ORDER BY Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                participantes.add(
                        mapearParticipante(rs));
            }
        }

        return participantes;
    }

    public List<Participante> listarParticipantesActivos()
            throws SQLException {

        List<Participante> participantes =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "IdParticipante, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "TipoParticipante, "
                + "Activo "
                + "FROM dbo.Participante "
                + "WHERE Activo = 1 "
                + "ORDER BY Nombre";

        try (Connection conexion = ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                participantes.add(
                        mapearParticipante(rs));
            }
        }

        return participantes;
    }

    public List<Participante> listarParticipantesPorDeporte(
            int idDeporte)
            throws SQLException {

        List<Participante> participantes =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "IdParticipante, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "TipoParticipante, "
                + "Activo "
                + "FROM dbo.Participante "
                + "WHERE IdDeporte = ? "
                + "AND Activo = 1 "
                + "ORDER BY Nombre";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(1, idDeporte);

            try (ResultSet rs =
                         ps.executeQuery()) {

                while (rs.next()) {
                    participantes.add(
                            mapearParticipante(rs));
                }
            }
        }

        return participantes;
    }

    public Participante buscarPorId(
            int idParticipante)
            throws SQLException {

        String sql =
                "SELECT "
                + "IdParticipante, "
                + "IdDeporte, "
                + "IdPais, "
                + "Nombre, "
                + "TipoParticipante, "
                + "Activo "
                + "FROM dbo.Participante "
                + "WHERE IdParticipante = ?";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(1, idParticipante);

            try (ResultSet rs =
                         ps.executeQuery()) {

                if (rs.next()) {
                    return mapearParticipante(rs);
                }
            }
        }

        return null;
    }

    /** Consulta administrativa de solo lectura; filtros parametrizados y paginacion SQL. */
    protected Connection obtenerConexionCatalogo() throws SQLException {
        return ConexionBD.obtenerConexion();
    }

    public com.apuestas.modelo.PaginaParticipantes listarPaginados(Integer idDeporte,String buscar,
            Boolean activo,int pagina,int tamanoPagina) throws SQLException {
        return listarCatalogo(null,idDeporte,buscar,activo,pagina,tamanoPagina);
    }

    public com.apuestas.modelo.PaginaParticipantes listarPaginadosPorLiga(int idLiga,Integer idDeporte,String buscar,
            Boolean activo,int pagina,int tamanoPagina) throws SQLException {
        if(idLiga<=0) throw new IllegalArgumentException();
        return listarCatalogo(idLiga,idDeporte,buscar,activo,pagina,tamanoPagina);
    }

    private com.apuestas.modelo.PaginaParticipantes listarCatalogo(Integer idLiga,Integer idDeporte,String buscar,
            Boolean activo,int pagina,int tamanoPagina) throws SQLException {
        long offset=((long)pagina-1)*tamanoPagina;
        if(pagina<1||tamanoPagina<1||tamanoPagina>100||offset>Integer.MAX_VALUE
                ||(idDeporte!=null&&idDeporte<=0)||buscar==null||buscar.length()>150) {
            throw new IllegalArgumentException();
        }
        // Solo fragmentos constantes. Ningun valor recibido se concatena en SQL.
        String where=" WHERE 1=1";
        if(idLiga!=null) where+=" AND EXISTS(SELECT 1 FROM dbo.LigaParticipante LP JOIN dbo.Liga L ON L.IdLiga=LP.IdLiga"
                +" WHERE LP.IdLiga = ? AND LP.IdParticipante=Participante.IdParticipante AND LP.Activo=1"
                +" AND L.Activo=1 AND L.IdDeporte=Participante.IdDeporte)";
        if(idDeporte!=null) where+=" AND IdDeporte = ?";
        if(!buscar.isEmpty()) where+=" AND Nombre LIKE ? ESCAPE '!'";
        if(activo!=null) where+=" AND Activo = ?";
        try(Connection c=obtenerConexionCatalogo()) {
            if(idLiga!=null) {
                try(PreparedStatement ps=c.prepareStatement("SELECT IdDeporte FROM dbo.Liga WHERE IdLiga = ?")) {
                    ps.setInt(1,idLiga);
                    try(ResultSet rs=ps.executeQuery()) {
                        if(!rs.next()) throw new SQLException("La liga no existe.","P0001",76601);
                        int deporte=rs.getInt("IdDeporte");
                        if(idDeporte!=null && deporte!=idDeporte)
                            throw new SQLException("Liga y deporte incompatibles.","P0001",76603);
                    }
                }
            }
            long total;
            try(PreparedStatement ps=c.prepareStatement("SELECT COUNT_BIG(*) AS Total FROM dbo.Participante"+where)) {
                parametrosCatalogoLiga(ps,idLiga,idDeporte,buscar,activo);
                try(ResultSet rs=ps.executeQuery()) {
                    if(!rs.next()||!(rs.getObject("Total") instanceof Long)) throw new SQLException("Conteo de catalogo inconsistente.");
                    total=(Long)rs.getObject("Total");
                    if(total<0||rs.next()) throw new SQLException("Conteo de catalogo inconsistente.");
                }
            }
            List<Participante> filas=new ArrayList<>();
            try(PreparedStatement ps=c.prepareStatement("SELECT IdParticipante, IdDeporte, IdPais, Nombre, TipoParticipante, Activo"
                    +" FROM dbo.Participante"+where+" ORDER BY Nombre, IdParticipante OFFSET ? ROWS FETCH NEXT ? ROWS ONLY")) {
                int siguiente=parametrosCatalogoLiga(ps,idLiga,idDeporte,buscar,activo);
                ps.setLong(siguiente,offset);ps.setInt(siguiente+1,tamanoPagina);
                try(ResultSet rs=ps.executeQuery()) {
                    while(rs.next()) {
                        if(filas.size()>=tamanoPagina) throw new SQLException("Pagina de catalogo inconsistente.");
                        filas.add(mapearParticipante(rs));
                    }
                }
            }
            return new com.apuestas.modelo.PaginaParticipantes(pagina,tamanoPagina,total,filas);
        }
    }

    private static int parametrosCatalogoLiga(PreparedStatement ps,Integer liga,Integer deporte,String buscar,Boolean activo)
            throws SQLException {
        if(liga==null) return parametrosCatalogo(ps,deporte,buscar,activo);
        ps.setInt(1,liga);
        int pos=2;
        if(deporte!=null) ps.setInt(pos++,deporte);
        if(!buscar.isEmpty()) ps.setString(pos++,"%"+buscar.replace("!","!!").replace("%","!%")
                .replace("_","!_").replace("[","![").replace("]","!]")+"%");
        if(activo!=null) ps.setBoolean(pos++,activo);
        return pos;
    }

    private static int parametrosCatalogo(PreparedStatement ps,Integer deporte,String buscar,Boolean activo)
            throws SQLException {
        int pos=1;
        if(deporte!=null) ps.setInt(pos++,deporte);
        if(!buscar.isEmpty()) {
            String literal=buscar.replace("!","!!").replace("%","!%")
                    .replace("_","!_").replace("[","![").replace("]","!]");
            ps.setString(pos++,"%"+literal+"%");
        }
        if(activo!=null) ps.setBoolean(pos++,activo);
        return pos;
    }

    private Participante mapearParticipante(
            ResultSet rs)
            throws SQLException {

        Participante participante =
                new Participante();

        participante.setIdParticipante(
                rs.getInt("IdParticipante"));

        participante.setIdDeporte(
                rs.getInt("IdDeporte"));

        int idPais =
                rs.getInt("IdPais");

        if (rs.wasNull()) {
            participante.setIdPais(null);
        } else {
            participante.setIdPais(idPais);
        }

        participante.setNombre(
                rs.getString("Nombre"));

        participante.setTipoParticipante(
                rs.getString("TipoParticipante"));

        participante.setActivo(
                rs.getBoolean("Activo"));

        return participante;
    }

    private void establecerIp(
            CallableStatement cs,
            int parametro,
            String ipOrigen)
            throws SQLException {

        if (ipOrigen != null
                && !ipOrigen.trim().isEmpty()) {

            cs.setString(parametro, ipOrigen);

        } else {

            cs.setNull(
                    parametro,
                    Types.VARCHAR);
        }
    }
}