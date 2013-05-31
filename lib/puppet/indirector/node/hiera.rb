require 'hiera_puppet'

class Puppet::Node::Hiera < Puppet::Indirector::Plain

  desc "Classify nodes in Hiera via discovered context derived from the Certificate Name"

  # Look for external node definitions
  def find(request)
    node = super or return nil

    populate_node(request.key, node)
  end

  private

  # Populate our node with Hiera results
  def populate_node(key, node)
    cert_scope = create_cert_scope(key, node)

    # Search for classes
    classes = HieraPuppet.lookup('classes', nil, cert_scope, nil, :hash) || {}

    # translate namespace resolution operators
    classes.each do |k,v|
      classes[k.gsub('.', '::')] = v
      classes.delete(k) if k =~ /\./
    end

    # put the things Hiera discovered into our node
    node.classes     = classes
    node.parameters  = HieraPuppet.lookup('parameters', nil, cert_scope, nil, :hash) || {}

    # TODO: the Hiera lookup for this keeps failing.  debug it
    #node.environment = env if env

    # merge new facts into existing facts - is this needed if we don't screw with facts?
    node.fact_merge
    node
  end

  def create_cert_scope(key, node)
    # Create new scope that will only be populated with data derived from tokenizing the certname
    scope = Puppet::Parser::Scope.new

    # Get Facts from Indirector
    facts = Puppet::Node::Facts.indirection.find(key).values rescue {}

    # Add discovered context to our temporary scope
    facts.each do |fact, value|
      scope.setvar(fact, value)
    end

    scope
  end
end
