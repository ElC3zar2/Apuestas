// =========================================================
// BETZONE — login.jsp
// Floating labels, mostrar/ocultar contraseña y validación
// =========================================================

document.addEventListener("DOMContentLoaded", () => {
  initPasswordToggles();
  initFloatingLabels();
  initLoginForm();
});

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Alterna la visibilidad de los inputs de contraseña
 * que tengan un botón .field__toggle asociado.
 */
function initPasswordToggles() {
  document.querySelectorAll(".field__toggle").forEach((btn) => {
    btn.addEventListener("click", () => {
      const input = document.getElementById(btn.dataset.target);
      if (!input) return;
      const showing = input.type === "text";
      input.type = showing ? "password" : "text";
      btn.classList.toggle("is-active", !showing);
      btn.setAttribute(
        "aria-label",
        showing ? "Mostrar contraseña" : "Ocultar contraseña"
      );
    });
  });
}

/**
 * Fallback en JS para navegadores donde :placeholder-shown
 * no cubra casos de autocompletado del navegador.
 */
function initFloatingLabels() {
  document.querySelectorAll(".field__input").forEach((input) => {
    const sync = () => input.classList.toggle("has-value", input.value.length > 0);
    input.addEventListener("input", sync);
    input.addEventListener("blur", sync);
    sync();
  });
}

function setFieldError(inputEl, errorEl, message) {
  if (message) {
    inputEl.classList.add("is-invalid");
    if (errorEl) errorEl.textContent = message;
    return false;
  }
  inputEl.classList.remove("is-invalid");
  if (errorEl) errorEl.textContent = "";
  return true;
}

function showAlert(alertEl, message, type) {
  if (!alertEl) return;
  alertEl.textContent = message;
  alertEl.classList.remove("form-alert--error", "form-alert--success");
  alertEl.classList.add(type === "success" ? "form-alert--success" : "form-alert--error", "is-visible");
}

/**
 * Validación del formulario de login:
 * - Ningún campo vacío.
 * - Correo con formato válido.
 */
function initLoginForm() {
  const form = document.getElementById("form-login");
  if (!form) return;

  const email = document.getElementById("login-email");
  const password = document.getElementById("login-password");
  const emailError = document.getElementById("login-email-error");
  const passwordError = document.getElementById("login-password-error");
  const alertBox = document.getElementById("login-alert");

  form.addEventListener("submit", (e) => {
    e.preventDefault();

    let valid = true;

    if (email.value.trim() === "") {
      valid = setFieldError(email, emailError, "Ingresá tu correo electrónico.") && valid;
    } else if (!EMAIL_REGEX.test(email.value.trim())) {
      valid = setFieldError(email, emailError, "El formato del correo no es válido.") && valid;
    } else {
      setFieldError(email, emailError, null);
    }

    if (password.value === "") {
      valid = setFieldError(password, passwordError, "Ingresá tu contraseña.") && valid;
    } else {
      setFieldError(password, passwordError, null);
    }

    if (!valid) {
      showAlert(alertBox, "Revisá los campos marcados en rojo.", "error");
      return;
    }

    showAlert(alertBox, "Verificando datos...", "success");
    form.submit();
  });
}


