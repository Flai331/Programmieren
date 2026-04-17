import { Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Invoices from './pages/Invoices';
import InvoiceCreate from './pages/InvoiceCreate';
import InvoiceDetail from './pages/InvoiceDetail';
import Customers from './pages/Customers';
import CustomerDetail from './pages/CustomerDetail';
import Articles from './pages/Articles';
import Templates from './pages/Templates';
import Statistics from './pages/Statistics';

function App() {
  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<Dashboard />} />

        <Route path="invoices">
          <Route index element={<Invoices />} />
          <Route path="new" element={<InvoiceCreate />} />
          <Route path=":id" element={<InvoiceDetail />} />
        </Route>

        <Route path="customers">
          <Route index element={<Customers />} />
          <Route path=":id" element={<CustomerDetail />} />
        </Route>

        <Route path="articles" element={<Articles />} />
        <Route path="templates" element={<Templates />} />
        <Route path="statistics" element={<Statistics />} />
      </Route>
    </Routes>
  );
}

export default App;
