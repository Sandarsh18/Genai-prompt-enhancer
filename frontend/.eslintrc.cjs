module.exports = {
  env: {
    browser: true,
    es2022: true
  },
  extends: ['standard', 'plugin:react/recommended'],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module'
  },
  plugins: ['react'],
  rules: {
    'react/react-in-jsx-scope': 'off'
  }
}
