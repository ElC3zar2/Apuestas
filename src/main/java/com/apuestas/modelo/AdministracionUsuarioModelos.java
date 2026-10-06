package com.apuestas.modelo;
import java.time.*; import java.math.BigDecimal; import java.util.List;
/** DTO explicitos. No contienen credenciales ni datos internos de bloqueo. */
public final class AdministracionUsuarioModelos {
 private AdministracionUsuarioModelos() { }
 public static abstract class ResultadoAccion { public Integer idUsuario; }
 public static final class Detalle { public Cuenta usuario; public List<Verificacion> verificaciones; public List<Restriccion> restricciones; }
 public static final class Cuenta {
  public Integer idUsuario;
  public String correo;
  public Boolean correoVerificado;
  public LocalDateTime fechaRegistro;
  public String rol;
  public String estadoUsuario;
  public String nombreEstadoUsuario;
  public String nombre;
  public String apellido;
  public LocalDate fechaNacimiento;
  public String genero;
  public String telefono;
  public String tipoDocumento;
  public String numeroDocumento;
  public Integer idPais;
  public String codigoISO2;
  public String pais;
  public Integer idDepartamento;
  public String departamento;
  public Integer idMunicipio;
  public String municipio;
  public String ciudadExterior;
  public String direccion;
  public LocalDateTime fechaActualizacion;
  public Integer idBilletera;
  public BigDecimal saldoDisponible;
  public BigDecimal saldoComprometido;
  public BigDecimal saldoVirtualTotal;
 }
 public static final class Pendiente {
  public Integer idUsuario;
  public String correo;
  public Boolean correoVerificado;
  public String estadoUsuario;
  public String nombre;
  public String apellido;
  public LocalDate fechaNacimiento;
  public String tipoDocumento;
  public String numeroDocumento;
  public String codigoISO2;
  public String pais;
  public String departamento;
  public String municipio;
  public String ciudadExterior;
  public String direccion;
  public Integer idVerificacion;
  public String estadoVerificacion;
  public LocalDateTime fechaSolicitud;
  public LocalDateTime fechaInicioRevision;
  public Integer idUsuarioRevisor;
  public String usuarioRevisor;
 }
 public static final class Verificacion {
  public Integer idVerificacion;
  public String estadoVerificacion;
  public String nombreEstadoVerificacion;
  public LocalDateTime fechaSolicitud;
  public LocalDateTime fechaInicioRevision;
  public LocalDateTime fechaResolucion;
  public Integer idUsuarioRevisor;
  public String usuarioRevisor;
  public String observacion;
 }
 public static final class Restriccion {
  public Integer idRestriccion;
  public String tipoRestriccion;
  public String motivo;
  public LocalDateTime fechaInicio;
  public LocalDateTime fechaFin;
  public Boolean activa;
  public LocalDateTime fechaRegistro;
  public Integer idUsuarioRegistro;
  public String usuarioRegistro;
  public Boolean vigente;
 }
 public static final class Revision extends ResultadoAccion {
  public Integer idVerificacion;
  public String estadoVerificacion;
  public Boolean sinCambios;
 }
 public static final class Aprobacion extends ResultadoAccion {
  public Integer idVerificacion;
  public String estadoVerificacion;
  public String estadoUsuario;
  public Boolean correoVerificado;
  public Boolean sinCambios;
 }
 public static final class Rechazo extends ResultadoAccion {
  public Integer idVerificacion;
  public String estadoVerificacion;
  public String estadoUsuario;
  public Boolean sinCambios;
 }
 public static final class Reapertura extends ResultadoAccion {
  public Integer idVerificacion;
  public String estadoVerificacion;
 }
 public static final class CambioEstado extends ResultadoAccion {
  public String estadoAnterior;
  public String estadoActual;
  public Boolean sinCambios;
 }
 public static final class RestriccionAgregada extends ResultadoAccion {
  public Integer idRestriccion;
  public String tipoRestriccion;
  public String motivo;
  public LocalDateTime fechaFin;
  public Boolean activa;
 }
 public static final class RestriccionLevantada extends ResultadoAccion {
  public Integer idRestriccion;
  public String tipoRestriccion;
  public Boolean activa;
  public Boolean sinCambios;
 }
}
