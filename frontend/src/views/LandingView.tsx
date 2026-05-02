import Navbar from "@/components/Navbar";
import Hero from "@/components/Hero";
import Marquee from "@/components/Marquee";
import FeedSection from "@/components/FeedSection";
import Manifesto from "@/components/Manifesto";
import FAQ from "@/components/FAQ";
import CTASection from "@/components/CTASection";
import Footer from "@/components/Footer";

const LandingView = () => {
  return (
    <main className="min-h-screen">
      <Navbar />
      <Hero />
      <Marquee />
      <FeedSection />
      <Manifesto />
      <FAQ />
      <CTASection />
      <Footer />
    </main>
  );
};

export default LandingView;
