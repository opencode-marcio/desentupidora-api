function validate(schema) {
  return (req, res, next) => {
    const errors = [];
    for (const [field, rules] of Object.entries(schema)) {
      const value = req.body[field];
      if (rules.required && (!value || (typeof value === 'string' && !value.trim()))) {
        errors.push(`${field} é obrigatório`);
      }
      if (value && rules.type === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
        errors.push(`${field} inválido`);
      }
      if (value && rules.minLength && value.length < rules.minLength) {
        errors.push(`${field} deve ter no mínimo ${rules.minLength} caracteres`);
      }
    }
    if (errors.length > 0) {
      return res.status(400).json({ error: errors.join('; ') });
    }
    next();
  };
}

module.exports = validate;
