import { isAuthenticated } from "@/lib/auth";

import Index from "./Index";
import Portal from "./Portal";

const Home = () => {
  return isAuthenticated() ? <Portal /> : <Index />;
};

export default Home;
