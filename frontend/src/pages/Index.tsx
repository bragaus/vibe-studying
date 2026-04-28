import Navbar from "@/components/Navbar";
import Hero from "@/components/Hero";
import Marquee from "@/components/Marquee";
import FeedSection from "@/components/FeedSection";
import StackSection from "@/components/StackSection";
import Manifesto from "@/components/Manifesto";
import FAQ from "@/components/FAQ";
import CTASection from "@/components/CTASection";
import Footer from "@/components/Footer";

const Index = () => {
  return (
    <main className="min-h-screen">
      <Navbar />
      <Hero />
      <Marquee />
      <FeedSection />
      <StackSection />
      <Manifesto />
      <FAQ />
      <CTASection />
      <Footer />
    </main>
  );
};

export default Index;
